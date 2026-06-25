## Setup SNS email messaging for Autoscale event notifications
resource "aws_sns_topic" "this" {
  name              = var.name
  kms_master_key_id = try(var.sns_kms_key_id, null)
}

resource "aws_sns_topic_subscription" "this" {
  topic_arn = aws_sns_topic.this.arn
  protocol  = "email"
  endpoint  = var.sns_email
}

resource "aws_autoscaling_notification" "this" {
  group_names   = var.autoscale_groups
  notifications = var.notifications
  topic_arn     = aws_sns_topic.this.arn
}


