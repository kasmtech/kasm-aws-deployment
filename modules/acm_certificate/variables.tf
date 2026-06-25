variable "domain_name" {
  description = ""
  type        = string
}

variable "subject_alternative_names" {
  description = ""
  type        = list(string)
  default     = []
}

variable "zone_id" {
  description = ""
  type        = string
}

