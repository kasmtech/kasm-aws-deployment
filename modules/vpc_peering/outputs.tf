output "requester_peer_id" {
  description = "The VPC peering ID of the requester"
  value       = try(aws_vpc_peering_connection.requester.id, null)
}

output "accepter_peer_id" {
  description = "The VPC peering ID of the accepter"
  value       = try(aws_vpc_peering_connection_accepter.accepter.id, null)
}