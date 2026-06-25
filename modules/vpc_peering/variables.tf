variable "requester_routes" {
  description = "VPC Requester Routes to add to peering connections"
  type = list(object({
    route_table_id   = string
    destination_cidr = string
  }))
}

variable "accepter_routes" {
  description = "VPC Accepter Routes to add to peering connections"
  type = list(object({
    route_table_id   = string
    destination_cidr = string
  }))
}

## Pre-set values
variable "accepter_region" {
  description = "The region of the Accepting VPC, or the Kasm Agent region"
  type        = string
}

variable "accepter_vpc_id" {
  description = "VPC ID of the accepter, or Kasm Management VPC"
  type        = string
}

variable "requester_vpc_id" {
  description = "VPC ID of the requester, or Kasm Agent VPC"
  type        = string
}
