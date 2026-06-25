output "secret_arn" {
  description = "ARN of the AWS Secrets Manager secret."
  value       = aws_secretsmanager_secret.this.arn
}

output "secret_id" {
  description = "ID of the AWS Secrets Manager secret (equal to its ARN)."
  value       = aws_secretsmanager_secret.this.id
}

output "secret_name" {
  description = "Name of the AWS Secrets Manager secret."
  value       = aws_secretsmanager_secret.this.name
}
