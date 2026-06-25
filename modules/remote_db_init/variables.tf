variable "ami_id" {
  description = "Pre-resolved AMI ID for the ephemeral init host. Caller selects between an override and the default aws_ami data source."
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID used to construct the SSM Parameter ARN granted in the IAM policy."
  type        = string
}

variable "db_backup_bucket_name" {
  description = "S3 bucket holding the rendered default_properties.yaml preseed. Read by the init job and granted via the IAM policy."
  type        = string
}

variable "force_init" {
  description = "Whether or not to force init the remote db"
  type        = bool
  default     = false
}

variable "generate_db_preseed" {
  description = "When true, the init job pulls a rendered default_properties.yaml from S3. When false, the installer falls back to its built-in seed (no S3 object needed)."
  type        = bool
}

variable "image_type" {
  description = "Kasm image_type passed through to db_init_userdata.sh (selects installer flavor)."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the ephemeral init host."
  type        = string
}

variable "kasm_download_url" {
  description = "Kasm installer download URL passed through to db_init_userdata.sh."
  type        = string
}

variable "kasm_version" {
  description = "Kasm version. Used to construct the preseed S3 object key."
  type        = string
}

variable "primary_region" {
  description = "Primary AWS region. The init stack only runs here; secondaries forward writes to the global cluster."
  type        = string
}

variable "private_domain" {
  description = "Private DNS zone (e.g. private.kasm.example.com). Combined with the region to form the DB hostname."
  type        = string
}

variable "rds_database_name" {
  description = "Aurora cluster database name passed to the installer."
  type        = string
}

variable "rds_master_username" {
  description = "Aurora master username passed to the installer."
  type        = string
}

variable "resource_name_prefix" {
  description = "Prefix used for IAM policy, role, instance-profile, and EC2 tag names. Mirrors the value from the calling root module."
  type        = string
}

variable "run_remote_db_init" {
  description = "Operator gate for the one-shot Aurora preseed job. Combined with var.use_rds to determine whether the EC2/IAM stack is created on this apply."
  type        = bool
}

variable "security_group_id" {
  description = "Webapp security group ID in the primary region. The init EC2 needs the same egress profile as a webapp to reach Aurora and the public installer endpoint."
  type        = string
}

variable "sm_admin_cred_arn" {
  description = "ARN of the Secrets Manager secret holding the Kasm admin user credential. Granted read-only via the IAM policy."
  type        = string
}

variable "sm_system_cred_arn" {
  description = "ARN of the Secrets Manager secret holding system credentials (db, service, manager tokens). Granted read-only via the IAM policy."
  type        = string
}

variable "sm_user_cred_arn" {
  description = "ARN of the Secrets Manager secret holding the Kasm user credential. Granted read-only via the IAM policy."
  type        = string
}

variable "standard_customer_name" {
  description = "Sanitized customer slug. Used to construct SM secret IDs (consumed by the userdata script) and the SSM status parameter name."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where the ephemeral init EC2 is launched. Must have egress to Aurora and the public installer endpoint."
  type        = string
}

variable "use_rds" {
  description = "Whether the deployment uses Aurora RDS. Independent of run_remote_db_init: when use_rds = true the SSM status parameter is still created so operators can observe init state across re-flips of run_remote_db_init."
  type        = bool
}

variable "userdata_dir" {
  description = "Directory containing userdata templates selected by the calling root module."
  type        = string
}

variable "userdata_file" {
  description = "Remote DB init userdata template filename relative to userdata_dir."
  type        = string
}

variable "vpc_cidr" {
  description = "Primary-region VPC CIDR block. The module derives the in-VPC DNS resolver address (second IP) for use inside Docker bridges spawned by the installer."
  type        = string
}
