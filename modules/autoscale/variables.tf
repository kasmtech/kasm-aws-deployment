variable "ami_id" {
  description = "The AMI ID to use for the instance"
  type        = string
}

variable "block_device_id" {
  description = "A list of of EBS block device IDs"
  type        = string
  default     = null
}

variable "instance_profile_name" {
  description = "The instance profile name to use"
  type        = string
}

variable "instance_type" {
  description = "The instance type to use"
  type        = string
}

variable "metadata" {
  description = "Instance metadata options. Default values configure strict IMDSv2 for security."
  type = object({
    endpoint  = optional(string, "enabled")
    tokens    = optional(string, "optional")
    hop_limit = optional(number, 1)
    tags      = optional(string, null)
  })
  default = {
    endpoint  = "enabled"
    tokens    = "optional"
    hop_limit = 1
    tags      = null
  }
}

variable "name" {
  description = "The instance name"
  type        = string
}

variable "root_device" {
  description = "Root Boot disk configuration settings"
  type = list(object({
    delete      = optional(bool, true)
    hdd_size    = optional(number, 50)
    volume_type = optional(string, "gp2")
  }))
  default = [
    {
      delete       = true
      encrypt_disk = true
      hdd_size     = 80
      volume_type  = "gp2"
    }
  ]
}

variable "scale_group_settings" {
  description = "An object containing AWS Autoscale group configuration settings"
  type = object({
    name                = string
    description         = optional(string)
    min_size            = number
    max_size            = number
    subnet_ids          = list(string)
    health_check_period = number
    cool_down_period    = number
    health_check_type   = string
    min_health_percent  = number
  })
}

variable "security_group_ids" {
  description = "A list of of SG IDs"
  type        = list(string)
  default     = []
}

variable "ssh_key_name" {
  description = "The name of the SSH key to attach to the instance"
  type        = string
  default     = ""
}

variable "user_data" {
  description = "AWS Instance Base64 encoded User Data startup script"
  type        = string
}

variable "target_group_arns" {
  description = "A map of AWS Load Balancer Target Group ARNs to attach to the autoscale group"
  type        = map(string)
  default     = {}
}

## Pre-set values
variable "system_role" {
  description = "The AWS Instance server role to use in the instance name and description if neither is provided in the instance_settings or group_settings"
  type        = string
  default     = ""
}

variable "scale_policy" {
  description = "An object containing the Autoscale CPU Scaling policy settings"
  type = object({
    name        = optional(string)
    policy_type = string
    deploy_time = number
    metric_type = string
    target_load = number
  })
  default = {
    policy_type = "TargetTrackingScaling"
    deploy_time = 600
    metric_type = "ASGAverageCPUUtilization"
    target_load = 60
  }
}
