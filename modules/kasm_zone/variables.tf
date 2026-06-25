variable "zone_key" {
  description = "Zone identifier — region name for regional zones (e.g., \"us-east-1\") or LZ AZ name for Local Zones (e.g., \"us-east-1-bos-1a\"). Used as the prefix for owned target group names like \"<zone_key>-webapp-priv-tg\"."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID in which the zone's owned private target group lives (the placement region's VPC)."
  type        = string
}

variable "private_lb_listener_arn" {
  description = "HTTPS listener ARN of the placement-region private ALB. The zone's owned listener rule attaches here."
  type        = string
}

variable "private_host_header" {
  description = "Host header the private listener rule matches on — typically '<zone_key>.<private_domain>'."
  type        = string
}

variable "webapp_health_check" {
  description = "Health check config for the owned webapp private target group."
  type = object({
    enabled             = bool
    path                = string
    matcher             = number
    protocol            = string
    timeout_in_sec      = number
    interval_in_sec     = number
    healthy_threshold   = number
    unhealthy_threshold = number
    port                = number
  })
}

variable "deploy_cpx" {
  description = "Whether to deploy the cpx ASG for this Kasm zone"
  type        = bool
  default     = true
}

variable "ssh_key_name" {
  description = "The name of the SSH key to attach to both the webapp and cpx instances"
  type        = string
  default     = ""
}

variable "webapp_ami_id" {
  description = "The AMI ID to use for the webapp instance"
  type        = string
}

variable "webapp_instance_profile_name" {
  description = "The instance profile name to use for the webapp instances"
  type        = string
}

variable "webapp_instance_type" {
  description = "The instance type to use for the webapp instances"
  type        = string
}

variable "webapp_name" {
  description = "The webapp launch template name"
  type        = string
}

variable "webapp_scale_group_settings" {
  description = "An object containing AWS Autoscale group configuration settings for the webapp ASG"
  type = object({
    name                = string
    description         = optional(string)
    min_size            = optional(number, 2)
    max_size            = optional(number, 5)
    subnet_ids          = list(string)
    health_check_period = optional(number, 300)
    cool_down_period    = optional(number, 600)
    health_check_type   = optional(string, "ELB")
    min_health_percent  = optional(number, 50)
  })
}

variable "webapp_security_group_ids" {
  description = "A list of SG IDs to attach to the webapp instances"
  type        = list(string)
  default     = []
}

variable "webapp_system_role" {
  description = "The AWS Instance server role to use in the webapp instance name and description"
  type        = string
  default     = ""
}

variable "webapp_target_group_arns" {
  description = "External target group ARNs to attach to the webapp ASG, beyond the private TG that this module owns internally. Typically the per-zone and shared public TGs on the placement-region public ALB."
  type        = map(string)
  default     = {}
}

variable "webapp_user_data" {
  description = "AWS Instance Base64 encoded User Data startup script for the webapp instances"
  type        = string
}

variable "cpx_ami_id" {
  description = "The AMI ID to use for the cpx instance"
  type        = string
  default     = null
}

variable "cpx_instance_profile_name" {
  description = "The instance profile name to use for the cpx instances"
  type        = string
  default     = null
}

variable "cpx_instance_type" {
  description = "The instance type to use for the cpx instances"
  type        = string
  default     = null
}

variable "cpx_name" {
  description = "The cpx launch template name"
  type        = string
  default     = null
}

variable "cpx_scale_group_settings" {
  description = "An object containing AWS Autoscale group configuration settings for the cpx ASG"
  type = object({
    name                = string
    description         = optional(string)
    min_size            = number
    max_size            = number
    subnet_ids          = list(string)
    health_check_period = number
    cool_down_period    = number
    health_check_type   = string
    min_health_percent  = number
  })
  default = null
}

variable "cpx_security_group_ids" {
  description = "A list of SG IDs to attach to the cpx instances"
  type        = list(string)
  default     = []
}

variable "cpx_system_role" {
  description = "The AWS Instance server role to use in the cpx instance name and description"
  type        = string
  default     = ""
}

variable "cpx_user_data" {
  description = "AWS Instance Base64 encoded User Data startup script for the cpx instances"
  type        = string
  default     = null
}

variable "deploy_proxy" {
  description = "Whether to deploy the proxy ASG for this Kasm zone. Proxies run only in secondary regions today."
  type        = bool
  default     = false
}

variable "proxy_ami_id" {
  description = "The AMI ID to use for the proxy instance"
  type        = string
  default     = null
}

variable "proxy_instance_profile_name" {
  description = "The instance profile name to use for the proxy instances"
  type        = string
  default     = null
}

variable "proxy_instance_type" {
  description = "The instance type to use for the proxy instances"
  type        = string
  default     = null
}

variable "proxy_name" {
  description = "The proxy launch template name"
  type        = string
  default     = null
}

variable "proxy_scale_group_settings" {
  description = "An object containing AWS Autoscale group configuration settings for the proxy ASG"
  type = object({
    name                = string
    description         = optional(string)
    min_size            = number
    max_size            = number
    subnet_ids          = list(string)
    health_check_period = number
    cool_down_period    = number
    health_check_type   = string
    min_health_percent  = number
  })
  default = null
}

variable "proxy_security_group_ids" {
  description = "A list of SG IDs to attach to the proxy instances"
  type        = list(string)
  default     = []
}

variable "proxy_system_role" {
  description = "The AWS Instance server role to use in the proxy instance name and description"
  type        = string
  default     = ""
}

variable "proxy_target_group_arns" {
  description = "A map of AWS Load Balancer Target Group ARNs to attach to the proxy autoscale group"
  type        = map(string)
  default     = {}
}

variable "proxy_user_data" {
  description = "AWS Instance Base64 encoded User Data startup script for the proxy instances"
  type        = string
  default     = null
}

## Optional per-zone private DNS A-record. When private_dns is null, no record
## is created.
variable "private_dns" {
  description = "Per-zone private DNS A-record config. Set null to skip record creation."
  type = object({
    zone_id         = string
    record_name     = string
    lb_dns_name     = string
    lb_route53_zone = string
  })
  default = null
}

## Optional per-zone public DNS A-record. When public_dns is null, no record
## is created. Today this is populated only for Local Zone keys — regional
## zones' public DNS lives at the root (apex / latency-routed records in
## load-balancers.tf), which doesn't fit a 1:1-per-zone shape.
variable "public_dns" {
  description = "Per-zone public DNS A-record config. Set null to skip record creation."
  type = object({
    zone_id         = string
    record_name     = string
    lb_dns_name     = string
    lb_route53_zone = string
  })
  default = null
}
