variable "zone_id" {
  description = "ID of DNS zone"
  type        = string
}

variable "records" {
  description = "List of objects of DNS records"
  type        = any
  default     = []
}
