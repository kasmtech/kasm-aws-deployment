## Aurora Global Database cross-region failover automation.
##
## Deploys a CloudWatch alarm on the primary cluster, a Lambda that calls
## failover-global-cluster when the alarm fires, an EventBridge rule that wires
## the alarm to the Lambda, and an SNS topic for status notifications.
##
## Known limitation: all resources deploy in the provider's region (typically
## var.primary_region). If the primary region is lost in its entirety —
## including the regional CloudWatch and Lambda control planes — this
## automation cannot run and operators must execute the failover runbook
## manually. A future iteration may move the orchestration to a Route53-
## health-check + us-east-1 Lambda model to remove that dependency.

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

#######################################
##                                   ##
##         SNS Topic                 ##
##                                   ##
#######################################

resource "aws_sns_topic" "failover_events" {
  name              = "${var.name}-events"
  kms_master_key_id = "alias/aws/sns"

  tags = merge(var.freeform_tags, {
    Name = "${var.name}-events"
  })
}

resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.sns_email_subscribers)

  topic_arn = aws_sns_topic.failover_events.arn
  protocol  = "email"
  endpoint  = each.key
}

#######################################
##                                   ##
##         Lambda IAM                ##
##                                   ##
#######################################

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "failover_lambda" {
  name               = "${var.name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

  tags = var.freeform_tags
}

data "aws_iam_policy_document" "failover_lambda" {
  ## Global cluster discovery and failover. RDS does not support resource-level
  ## permissions for DescribeGlobalClusters or DescribeDBClusters, so both must
  ## be granted on "*". FailoverGlobalCluster is scoped to the specific global
  ## cluster ARN.
  statement {
    actions = [
      "rds:DescribeGlobalClusters",
      "rds:DescribeDBClusters",
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "rds:FailoverGlobalCluster",
    ]
    resources = [
      "arn:aws:rds::${data.aws_caller_identity.current.account_id}:global-cluster:${var.global_cluster_id}",
    ]
  }

  statement {
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.failover_events.arn]
  }

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.name}*",
    ]
  }
}

resource "aws_iam_policy" "failover_lambda" {
  name   = "${var.name}-lambda-policy"
  policy = data.aws_iam_policy_document.failover_lambda.json

  tags = var.freeform_tags
}

resource "aws_iam_role_policy_attachment" "failover_lambda" {
  role       = aws_iam_role.failover_lambda.name
  policy_arn = aws_iam_policy.failover_lambda.arn
}

#######################################
##                                   ##
##         Lambda Package            ##
##                                   ##
#######################################

data "archive_file" "failover" {
  type        = "zip"
  source_file = "${path.module}/lambda/failover.py"
  output_path = "${path.module}/lambda/failover.zip"
}

resource "aws_lambda_function" "failover" {
  function_name    = var.name
  role             = aws_iam_role.failover_lambda.arn
  runtime          = "python3.12"
  handler          = "failover.handler"
  filename         = data.archive_file.failover.output_path
  source_code_hash = data.archive_file.failover.output_base64sha256
  timeout          = 60
  memory_size      = 256

  environment {
    variables = {
      GLOBAL_CLUSTER_ID = var.global_cluster_id
      SNS_TOPIC_ARN     = aws_sns_topic.failover_events.arn
      ALLOW_DATA_LOSS   = var.allow_data_loss ? "true" : "false"
      LOG_LEVEL         = "INFO"
    }
  }

  tags = merge(var.freeform_tags, {
    Name = var.name
  })

  depends_on = [aws_iam_role_policy_attachment.failover_lambda]
}

#######################################
##                                   ##
##         CloudWatch Alarm          ##
##                                   ##
#######################################

resource "aws_cloudwatch_metric_alarm" "primary_unreachable" {
  alarm_name          = "${var.name}-primary-unreachable"
  alarm_description   = "Aurora primary cluster ${var.primary_cluster_id} is unreachable (metric data missing or zero connections for the evaluation window). Triggers automated failover."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = var.alarm_period_seconds
  statistic           = "SampleCount"
  threshold           = 1
  treat_missing_data  = "breaching"

  dimensions = {
    DBClusterIdentifier = var.primary_cluster_id
  }

  alarm_actions = [aws_sns_topic.failover_events.arn]
  ok_actions    = [aws_sns_topic.failover_events.arn]

  tags = var.freeform_tags
}

#######################################
##                                   ##
##         EventBridge Wiring        ##
##                                   ##
#######################################

resource "aws_cloudwatch_event_rule" "failover_trigger" {
  name        = "${var.name}-trigger"
  description = "Fires the failover Lambda when the primary-unreachable alarm transitions to ALARM."

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    resources   = [aws_cloudwatch_metric_alarm.primary_unreachable.arn]
    detail = {
      state = {
        value = ["ALARM"]
      }
    }
  })

  tags = var.freeform_tags
}

resource "aws_cloudwatch_event_target" "failover_lambda" {
  rule      = aws_cloudwatch_event_rule.failover_trigger.name
  target_id = "${var.name}-lambda-target"
  arn       = aws_lambda_function.failover.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.failover.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.failover_trigger.arn
}
