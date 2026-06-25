variable "upload_key" {
  description = "Used to upload the SSH key to the AWS key pair store"
  type        = bool
  default     = true
}

variable "key_name" {
  description = "AWS KMS key name to use for public SSH key"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH Public key to upload to AWS key manager"
  type        = string
  default     = ""

  validation {
    condition     = can(regex("ssh-(rsa AAAAB3NzaC1yc2E|ed25519 AAAAC3NzaC1lZDI1NTE5).*", var.ssh_public_key))
    error_message = "The ssh_public_key must be a valid SSH public key."
  }
}
