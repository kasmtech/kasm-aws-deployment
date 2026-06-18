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

variable "is_public" {
  description = "Whether or not to attach a public IP to the instance"
  type        = bool
  default     = false
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
    delete       = optional(bool, true)
    encrypt_disk = optional(bool, true)
    hdd_size     = optional(number, 80)
    volume_type  = optional(string, "gp2")
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

variable "subnet_id" {
  description = "The ID of the subnet to deploy the instance into"
  type        = string
}

variable "user_data" {
  description = "AWS Instance Base64 encoded User Data startup script"
  type        = string
}