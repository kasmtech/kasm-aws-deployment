output "global_cluster_id" {
  description = "ID of the aws_rds_global_cluster — pass to rds-secondary as global_cluster_id"
  value       = aws_rds_global_cluster.this.id
}

output "global_cluster_arn" {
  description = "ARN of the aws_rds_global_cluster"
  value       = aws_rds_global_cluster.this.arn
}

output "global_cluster_members" {
  description = "Set of clusters currently joined to the global cluster (refreshed from AWS each plan). Each entry has db_cluster_arn + is_writer. Used by the rds_secondaries_joined_to_global check block in database.tf to detect accidental console-promotions of secondaries."
  value       = aws_rds_global_cluster.this.global_cluster_members
}

output "primary_cluster_endpoint" {
  description = "Writer endpoint for the primary regional cluster — point application writes here"
  value       = aws_rds_cluster.primary.endpoint
}

output "primary_cluster_reader_endpoint" {
  description = "Reader endpoint for the primary regional cluster"
  value       = aws_rds_cluster.primary.reader_endpoint
}

output "primary_cluster_port" {
  description = "Port the cluster listens on"
  value       = aws_rds_cluster.primary.port
}

output "primary_cluster_id" {
  description = "Cluster identifier of the primary regional cluster"
  value       = aws_rds_cluster.primary.id
}

output "primary_cluster_arn" {
  description = "ARN of the primary regional cluster. Used by failover automation."
  value       = aws_rds_cluster.primary.arn
}

output "master_username" {
  description = "Master DB username"
  value       = aws_rds_cluster.primary.master_username
  sensitive   = true
}

output "master_password" {
  description = "Master DB password"
  value       = aws_rds_cluster.primary.master_password
  sensitive   = true
}