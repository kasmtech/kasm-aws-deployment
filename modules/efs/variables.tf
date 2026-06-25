variable "efs_share_name" {
  description = "Name to use for NFS share"
  type        = string
}

variable "is_encrypted" {
  description = "Used to encrypt the NFS filesystem. If set to true, the kms_key_id must also be set appropriately"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID to use for NFS filesystem encryption. Must be set if is_encrypted is set to true."
  type        = string
  default     = ""
}

variable "mount_target_settings" {
  description = "The mount target settings"
  type = map(object({
    subnet_id          = string
    security_group_ids = list(string)
  }))
}