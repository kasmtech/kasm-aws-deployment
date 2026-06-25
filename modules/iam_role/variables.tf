variable "role_name" {
  description = "Name of the IAM role to create."
  type        = string
}


variable "policy_arns" {
  description = "Map of policy name to IAM policy ARN to attach to the role."
  type        = map(string)
  default     = {}
}

variable "instance_profile_name" {
  description = "Instance profile name. If empty, role_name is used."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to the role and instance profile."
  type        = map(string)
  default     = {}
}
