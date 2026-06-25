#######################################
##                                   ##
##           Identity                ##
##                                   ##
#######################################

variable "name" {
  description = "Base name used for the regional cluster and instance identifiers (must match the rds-primary value so global cluster naming stays consistent)"
  type        = string
}

variable "region" {
  description = "AWS region this secondary (reader) cluster runs in. The aws provider passed to this module must be configured for this region."
  type        = string

  validation {
    condition     = can(regex("^([a-z]{2}-[a-z]{4,}-[\\d]{1})$", var.region))
    error_message = "region must be a valid AWS Region name, e.g. us-west-2."
  }
}

variable "source_region" {
  description = "AWS region of the writer (primary) cluster — required for cross-region replication"
  type        = string

  validation {
    condition     = can(regex("^([a-z]{2}-[a-z]{4,}-[\\d]{1})$", var.source_region))
    error_message = "source_region must be a valid AWS Region name, e.g. us-east-1."
  }
}

#######################################
##                                   ##
##         Global Cluster            ##
##                                   ##
#######################################

variable "global_cluster_id" {
  description = "ID of the aws_rds_global_cluster (output of rds-primary)"
  type        = string
}

#######################################
##                                   ##
##         Networking                ##
##                                   ##
#######################################

variable "db_subnet_group_name" {
  description = "DB subnet group for the secondary cluster"
  type        = string
}

variable "vpc_security_group_ids" {
  description = "Security groups attached to the secondary cluster"
  type        = list(string)
}

#######################################
##                                   ##
##         Engine and Sizing         ##
##                                   ##
#######################################

variable "engine" {
  description = "Aurora engine. Must match the primary cluster."
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
  description = "Database engine version. Must match the primary cluster."
  type        = string
}

variable "instance_class" {
  description = "Default instance class for cluster instances. Overridable per-instance via var.instances."
  type        = string
  default     = "db.r6g.large"
}

variable "instances" {
  description = "Map of cluster instances to create in this regional cluster. Each entry may override instance_class, monitoring_interval, performance_insights_enabled, promotion_tier, apply_immediately, and auto_minor_version_upgrade."
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

#######################################
##                                   ##
##       Global Write Forwarding     ##
##                                   ##
#######################################

variable "enable_write_forwarding" {
  description = "Enable global write-forwarding on this secondary cluster. When true, writes against this cluster's endpoint are transparently forwarded to the global writer. Requires Aurora engine versions that support write-forwarding (Aurora PostgreSQL 14.6+ / 15.x, Aurora MySQL 3.04+)."
  type        = bool
  default     = true
}