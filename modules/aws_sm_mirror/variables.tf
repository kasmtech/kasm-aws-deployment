variable "secret_name" {
  description = "The AWS Secrets Manager secret name. Must be stable across re-applies and unique within the AWS account/region."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9/_+=.@-]{1,512}$", var.secret_name))
    error_message = "secret_name must be 1-512 characters and match the AWS Secrets Manager name charset (letters, digits, and /_+=.@-)."
  }
}

variable "secret_description" {
  description = "Optional description attached to the AWS Secrets Manager secret. Surfaces in the AWS console for human operators."
  type        = string
  default     = ""
}

variable "secret_payload" {
  description = "Arbitrary JSON-encodable map of secret content. The caller shapes this however is most natural for SM consumers; the module just jsonencodes it and stores it as the secret value."
  type        = any
}

variable "recovery_window_in_days" {
  description = "AWS Secrets Manager recovery window. Default is 7 days. Set to 0 only when you need immediate-delete semantics for tear-down workflows."
  type        = number
  default     = 7

  validation {
    condition     = var.recovery_window_in_days == 0 || (var.recovery_window_in_days >= 7 && var.recovery_window_in_days <= 30)
    error_message = "recovery_window_in_days must be 0 (immediate delete) or between 7 and 30 (AWS-allowed range)."
  }
}

variable "tags" {
  description = "Additional tags to attach to the secret. Merged on top of the provider default_tags."
  type        = map(string)
  default     = {}
}
