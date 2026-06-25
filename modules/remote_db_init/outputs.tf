output "ssm_status_param_name" {
  description = "SSM Parameter Store name where the init EC2 writes its success/skip marker. Operators poll this to confirm preseed completion before flipping run_remote_db_init back to false."
  value       = local.ssm_status_param_name
}

output "instance_id" {
  description = "EC2 instance ID of the ephemeral init host. Empty string when run_remote_db_init is disabled."
  value       = local.run_remote_db_init ? aws_instance.initializer[0].id : ""
}
