variable "zone_id" {
  description = "The Route53 Private zone ID to attach to the VPC"
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID to attach to the Route53 Private zone"
  type        = string
}