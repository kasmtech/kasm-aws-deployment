variable "persistent_profile_s3_user_arn" {
  description = "ARN of AWS user created for S3-based Kasm persistent profiles"
  type        = string
}

## Pre-set values
variable "bucket_name" {
  description = "Optional: S3 Persistent profile bucket name - Must be globally unique."
  type        = string
  default     = ""
}

variable "bucket_base_name" {
  description = "Optional: S3 Persistent profile bucket base name combined with random number to generate unique name"
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Optional: Kasm project name to use in place of bucket_base_name for S3 bucket name prefix"
  type        = string
  default     = ""
}

variable "forward_logs" {
  description = "Forward S3 bucket access and API logs to another S3 bucket"
  type        = bool
  default     = false
}

variable "s3_logging_bucket" {
  description = "The S3 logging bucket where logs are to be forwarded"
  type        = string
  default     = ""
}

variable "s3_target_log_folder" {
  description = "The folder path where logs are to be stored"
  type        = string
  default     = "s3/persistent_profiles/"
}

variable "kms_key_id" {
  description = "The Customer-managed KMS key to use to encrypt the S3 bucket"
  type        = string
  default     = ""
}

variable "tiering_config" {
  description = "S3 Bucket auto-tiering configuration settings"
  type = list(object({
    access_tier = string
    days        = number
  }))
  default = [
    {
      access_tier = "ARCHIVE_ACCESS"
      days        = 120
    },
    {
      access_tier = "DEEP_ARCHIVE_ACCESS"
      days        = 180
    }
  ]
}

