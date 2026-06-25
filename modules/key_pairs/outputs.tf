output "key_id" {
  description = "AWS KMS key id"
  value       = data.aws_key_pair.this.id
}
output "key_name" {
  description = "AWS KMS key name"
  value       = data.aws_key_pair.this.key_name
}