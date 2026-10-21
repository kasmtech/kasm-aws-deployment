output "secret_arn" {
  description = "ARN of the AWS Secrets Manager secret. Sourced from the secret version so consumers (e.g. instances that read it at boot) wait until the value exists."
  value       = aws_secretsmanager_secret_version.this.arn
}

output "secret_id" {
  description = "ID of the AWS Secrets Manager secret (equal to its ARN)."
  value       = aws_secretsmanager_secret.this.id
}

output "secret_name" {
  description = "Name of the AWS Secrets Manager secret."
  value       = aws_secretsmanager_secret.this.name
}
