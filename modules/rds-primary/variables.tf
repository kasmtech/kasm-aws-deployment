#######################################
##                                   ##
##           Identity                ##
##                                   ##
#######################################

variable "name" {
  description = "Base name used for the global cluster, primary cluster, and instance identifiers (e.g. \"<customer>-aurora\")"
  type        = string
}

variable "primary_region" {
  description = "AWS region hosting the writer cluster. The aws provider passed to this module must be configured for this region."
  type        = string

  validation {
    condition     = can(regex("^([a-z]{2}-[a-z]{4,}-[\\d]{1})$", var.primary_region))
    error_message = "primary_region must be a valid AWS Region name, e.g. us-east-1."
  }
}

#######################################
##                                   ##
##         Networking                ##
##                                   ##
#######################################

variable "db_subnet_group_name" {
  description = "DB subnet group for the primary cluster"
  type        = string
}

variable "vpc_security_group_ids" {
  description = "Security groups attached to the primary cluster"
  type        = list(string)
}

#######################################
##                                   ##
##         Engine and Sizing         ##
##                                   ##
#######################################

variable "engine" {
  description = "Aurora engine. Aurora Global Database does not support the legacy aurora engine."
  type        = string
  default     = "aurora-postgresql"

  validation {
    condition     = contains(["aurora-mysql", "aurora-postgresql"], var.engine)
    error_message = "engine must be aurora-mysql or aurora-postgresql for Aurora Global Database compatibility."
  }
}

variable "engine_mode" {
  description = "Database engine mode. Aurora Global Database requires provisioned."
  type        = string
  default     = "provisioned"
}

variable "engine_version" {
  description = "Database engine version. Must be a globally-supported Aurora version."
  type        = string
}

variable "database_name" {
  description = "Initial database name created on cluster bootstrap. Set to empty string to skip creating an initial database."
  type        = string
  default     = ""
}

variable "instance_class" {
  description = "Default instance class for cluster instances. Overridable per-instance via var.instances."
  type        = string
  default     = "db.r6g.large"
}

variable "instances" {
  description = "Map of cluster instances to create in the primary cluster. Each entry may override instance_class, monitoring_interval, performance_insights_enabled, promotion_tier, apply_immediately, auto_minor_version_upgrade, and availability_zone."
  type        = any
  default = {
    one = {}
  }
}

variable "port" {
  description = "Port the cluster listens on"
  type        = number
  default     = 5432
}

#######################################
##                                   ##
##           Credentials             ##
##                                   ##
#######################################

variable "master_username" {
  description = "Master DB user name. Set on the primary cluster only; secondaries inherit via the global cluster."
  type        = string
}

variable "master_password" {
  description = "Master DB password. Stored in state — treat state as sensitive."
  type        = string
  sensitive   = true
}

#######################################
##                                   ##
##        Backup / Maintenance       ##
##                                   ##
#######################################

variable "apply_immediately" {
  description = "Apply cluster modifications immediately rather than during the next maintenance window"
  type        = bool
  default     = null
}

variable "auto_minor_version_upgrade" {
  description = "Apply minor engine upgrades automatically during the maintenance window"
  type        = bool
  default     = null
}

variable "backup_retention_period" {
  description = "Days to retain automated backups"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Prevent the cluster from being deleted while true"
  type        = bool
  default     = true
}

variable "preferred_backup_window" {
  description = "Daily time range during which automated backups are created (UTC)"
  type        = string
  default     = "02:00-03:00"
}

variable "preferred_maintenance_window" {
  description = "Weekly time range during which system maintenance can occur (UTC)"
  type        = string
  default     = "sun:05:00-sun:06:00"
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot when destroying the cluster"
  type        = bool
  default     = false
}

#######################################
##                                   ##
##          Encryption / KMS         ##
##                                   ##
#######################################

variable "kms_key_id" {
  description = "ARN of the KMS key for encryption at rest. When set, storage_encrypted must be true."
  type        = string
  default     = null
}

#######################################
##                                   ##
##         Instance Behavior         ##
##                                   ##
#######################################

variable "monitoring_interval" {
  description = "Interval (seconds) between Enhanced Monitoring metric points. 0 disables."
  type        = number
  default     = 0
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights on cluster instances"
  type        = bool
  default     = false
}

variable "publicly_accessible" {
  description = "Make cluster instances publicly accessible"
  type        = bool
  default     = false
}

variable "serverlessv2_scaling_configuration" {
  description = "Aurora Serverless v2 ACU bounds (min_capacity, max_capacity). Leave empty for provisioned (non-serverless) instances."
  type        = map(number)
  default     = {}
}