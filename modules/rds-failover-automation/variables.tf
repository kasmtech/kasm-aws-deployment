#######################################
##                                   ##
##           Identity                ##
##                                   ##
#######################################

variable "name" {
  description = "Naming prefix applied to the SNS topic, Lambda, IAM role, EventBridge rule, and CloudWatch alarm (e.g. \"<customer>-aurora-failover\")"
  type        = string
}

#######################################
##                                   ##
##         Global Cluster            ##
##                                   ##
#######################################

variable "global_cluster_id" {
  description = "Aurora Global Database identifier (output of rds-primary)"
  type        = string
}

variable "primary_cluster_id" {
  description = "DB cluster identifier of the primary writer cluster — used as the CloudWatch alarm dimension"
  type        = string
}

#######################################
##                                   ##
##         Failover Policy           ##
##                                   ##
#######################################

variable "allow_data_loss" {
  description = "Whether the Lambda is permitted to call failover-global-cluster with AllowDataLoss=true. Set false to limit the automation to managed planned failovers only (requires a healthy primary)."
  type        = bool
  default     = true
}

#######################################
##                                   ##
##         Alarm Tuning              ##
##                                   ##
#######################################

variable "alarm_evaluation_periods" {
  description = "Number of consecutive alarm periods the primary cluster must be unreachable before failover is triggered"
  type        = number
  default     = 3

  validation {
    condition     = var.alarm_evaluation_periods >= 1 && var.alarm_evaluation_periods <= 10
    error_message = "alarm_evaluation_periods must be between 1 and 10."
  }
}

variable "alarm_period_seconds" {
  description = "CloudWatch alarm period in seconds. Must be one of 10, 30, 60, 300."
  type        = number
  default     = 60

  validation {
    condition     = contains([10, 30, 60, 300], var.alarm_period_seconds)
    error_message = "alarm_period_seconds must be one of 10, 30, 60, or 300."
  }
}

#######################################
##                                   ##
##         Notifications             ##
##                                   ##
#######################################

variable "sns_email_subscribers" {
  description = "Email addresses to subscribe to failover SNS notifications. Each subscription requires manual confirmation by the recipient."
  type        = list(string)
  default     = []
}

#######################################
##                                   ##
##         Tagging                   ##
##                                   ##
#######################################

variable "freeform_tags" {
  description = "Tags applied to all resources in this module"
  type        = map(string)
  default     = {}
}
