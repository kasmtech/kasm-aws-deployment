output "cluster_id" {
  description = "Cluster identifier of this secondary regional cluster"
  value       = aws_rds_cluster.this.id
}

output "cluster_arn" {
  description = "ARN of this secondary regional cluster. Used by failover automation to target this cluster as a promotion candidate."
  value       = aws_rds_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Writer endpoint of this secondary regional cluster. With write-forwarding enabled, writes against this endpoint are forwarded to the global writer; otherwise the endpoint is read-only until the cluster is promoted."
  value       = aws_rds_cluster.this.endpoint
}

output "reader_endpoint" {
  description = "Reader endpoint of this secondary regional cluster. Use this for in-region read traffic."
  value       = aws_rds_cluster.this.reader_endpoint
}