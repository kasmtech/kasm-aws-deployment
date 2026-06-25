output "sns_topic_arn" {
  description = "ARN of the SNS topic that receives failover status notifications. Subscribe additional endpoints (Slack webhook, PagerDuty, etc.) out-of-band."
  value       = aws_sns_topic.failover_events.arn
}

output "lambda_function_arn" {
  description = "ARN of the failover Lambda function"
  value       = aws_lambda_function.failover.arn
}

output "lambda_function_name" {
  description = "Name of the failover Lambda function"
  value       = aws_lambda_function.failover.function_name
}

output "alarm_arn" {
  description = "ARN of the CloudWatch alarm that monitors the primary cluster"
  value       = aws_cloudwatch_metric_alarm.primary_unreachable.arn
}

output "event_rule_arn" {
  description = "ARN of the EventBridge rule that wires the alarm to the Lambda"
  value       = aws_cloudwatch_event_rule.failover_trigger.arn
}
