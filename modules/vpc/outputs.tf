output "subnet_ids" {
  value = { for key, value in var.subnets : key => try(aws_subnet.this[(key)].id, null) }
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.this[0].id
}

output "vpc_arn" {
  description = "The ARN of the VPC"
  value       = try(aws_vpc.this[0].arn, null)
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = try(aws_vpc.this[0].cidr_block, null)
}
output "vpc_enable_dns_support" {
  description = "Whether or not the VPC has DNS support"
  value       = try(aws_vpc.this[0].enable_dns_support, null)
}

output "vpc_enable_dns_hostnames" {
  description = "Whether or not the VPC has DNS hostname support"
  value       = try(aws_vpc.this[0].enable_dns_hostnames, null)
}

output "igw_id" {
  description = "The ID of the Internet Gateway"
  value       = try(aws_internet_gateway.this.id, null)
}

output "igw_arn" {
  description = "The ARN of the Internet Gateway"
  value       = try(aws_internet_gateway.this.arn, null)
}

output "public_route_table_id" {
  description = "ID of public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "List of IDs of private route tables"
  value       = aws_route_table.private[*].id
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = { for key, value in var.subnets : key => try(aws_subnet.this[(key)].id, null) if value.is_public }
}

output "public_subnet_arns" {
  description = "List of IDs of public subnets"
  value       = { for key, value in var.subnets : key => try(aws_subnet.this[(key)].arn, null) if value.is_public }
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = { for key, value in var.subnets : key => try(aws_subnet.this[(key)].id, null) if !value.is_public }
}

output "private_subnet_arns" {
  description = "List of IDs of private subnets"
  value       = { for key, value in var.subnets : key => try(aws_subnet.this[(key)].arn, null) if !value.is_public }
}

output "database_subnet_group" {
  description = "ID of database subnet group"
  value       = try(aws_db_subnet_group.database[0].id, null)
}

output "nat_eip_ids" {
  description = "List of allocation ID of Elastic IPs created for AWS NAT Gateway"
  value       = try(aws_eip.nat[*].id, null)
}

output "nat_public_ips" {
  description = "List of public Elastic IPs created for AWS NAT Gateway"
  value       = try(aws_eip.nat[*].public_ip, null)
}

output "natgw_ids" {
  description = "List of NAT Gateway IDs"
  value       = try(aws_nat_gateway.this[*].id, null)
}

output "network_acl_ids" {
  description = "Map of Network ACLs to IDs"
  value       = { for value in local.distinct_nacls : value => try(aws_network_acl.this[(value)].id, null) }
}

output "security_group_ids" {
  description = "Map of Security Groups to IDs"
  value       = { for value in var.security_groups : value => try(aws_security_group.this[(value)].id, null) }
}
