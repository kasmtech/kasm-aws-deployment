variable "autoscale_groups" {
  description = "A list of Autoscale groups to create an SNS notification for"
  type        = list(string)
}

variable "name" {
  description = "SNS notification topic name"
  type        = string
}

variable "sns_email" {
  description = "Email address to receive SNS notifications"
  type        = string
}

## Pre-set values
variable "sns_kms_key_id" {
  description = "KMS Key to encrypt the SNS topic data"
  type        = string
  default     = ""
}

variable "notifications" {
  description = "List of AWS events to generate notifications from"
  type        = list(string)
  default = [
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR"
  ]
}

