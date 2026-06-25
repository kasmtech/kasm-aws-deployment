output "lb_arn" {
  description = "Load balancer ARN"
  value       = aws_lb.this.arn
}

output "lb_dns_name" {
  description = "Load balancer DNS name"
  value       = aws_lb.this.dns_name
}

output "lb_zone_id" {
  description = "Load balancer zone ID"
  value       = aws_lb.this.zone_id
}

output "target_group_arns" {
  description = "Target group ARNs"
  value       = [for tg in aws_lb_target_group.this : tg.arn]
}

output "target_group_arns_by_name" {
  description = "Target group ARNs keyed by target group name"
  value       = { for k, tg in aws_lb_target_group.this : k => tg.arn }
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener, for attaching listener rules from outside this module"
  value       = aws_lb_listener.https.arn
}
