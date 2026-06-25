output "asg_name" {
  description = "The name of the newly created Autoscale group"
  value       = aws_autoscaling_group.this.name
}

output "asg_arn" {
  description = "The ARN of the Autoscale group"
  value       = aws_autoscaling_group.this.arn
}

output "instance_template_arn" {
  description = "The ARN of the Instance template"
  value       = aws_launch_template.this.arn
}

