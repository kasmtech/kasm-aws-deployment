variable "ami_id" {
  description = "The AMI ID to use for the database instance"
  type        = string
}

variable "availability_zone" {
  description = "The availability zone in which to create the EBS block volume for the database"
  type        = string
}

variable "customer_name" {
  description = "Standardized customer name used as the prefix for the database instance Name tag and IAM policy"
  type        = string
}

variable "db_backup_bucket_name" {
  description = "Name of the S3 bucket the database instance is permitted to read/write backups to"
  type        = string
}

variable "db_block_volume_size" {
  description = "Size in GB of the EBS volume attached to the database instance"
  type        = number
  default     = 100

  validation {
    condition     = var.db_block_volume_size > 0
    error_message = "db_block_volume_size must be greater than 0."
  }
}

variable "db_instance_type" {
  description = "The EC2 instance type for the database server"
  type        = string
}

variable "kasminit_policy_arn" {
  description = "ARN of the kasminit IAM policy (created in the parent project) to attach to the db backup role"
  type        = string
}

variable "resource_name_prefix" {
  description = "Prefix used to construct the db backup IAM role and instance profile names (typically \"<customer>-<deployment_type>\")"
  type        = string
}

variable "security_group_ids" {
  description = "A list of security group IDs to attach to the database instance"
  type        = list(string)
}

variable "ssh_key_name" {
  description = "The name of the SSH key to attach to the database instance"
  type        = string
}

variable "subnet_id" {
  description = "The ID of the subnet to deploy the database instance into"
  type        = string
}

variable "user_data" {
  description = "Base64-encoded user-data startup script for the database instance"
  type        = string
}
