output "block_volume_id" {
  description = "The ID of the EBS volume attached to the database instance"
  value       = aws_ebs_volume.db_block_device.id
}

output "private_ip" {
  description = "Database instance private IP address"
  value       = module.database_instance.private_ip
}

output "public_ip" {
  description = "Database instance public IP address (if assigned)"
  value       = module.database_instance.public_ip
}
