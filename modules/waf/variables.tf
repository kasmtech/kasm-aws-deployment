variable "load_balancer_arns" {
  description = "Map of load balancers to associate with the WAF, keyed by load balancer name (used as the for_each key, so it must be known at plan time) with the LB ARN as the value."
  type        = map(string)
}

variable "admin_bypass_ips" {
  description = "Rule to allow designated IP addressess to bypass the WAF for administrative functions"
  type        = list(string)
}

# S3 Log Bucket settings
variable "waf_s3_bucket_arn" {
  description = "S3 log bucket ARN where Kasm WAF logs should be sent"
  type        = string
}

# Pre-set values
variable "name" {
  description = "Name for the WAF ACL resource. If unset, the name prefix is used to generate a generic name."
  type        = string
  default     = ""
}

variable "description" {
  description = "Description for the WAF ACL resource"
  type        = string
  default     = ""
}

variable "name_prefix" {
  description = "Kasm project name to use for label and name values"
  type        = string
  default     = ""
}

# Various settings
variable "waf_scope" {
  description = "Scope to use for this WAF deployment"
  type        = string
  default     = "REGIONAL"

  validation {
    condition     = contains(["REGIONAL"], var.waf_scope)
    error_message = "The waf_scope can only be one of REGIONAL or CLOUDFRONT. This deployment doesn't support CLOUDFRONT, so REGIONAL is currently the only supported value."
  }
}

variable "vendor_name" {
  description = "The Vendor name to use for the default rules"
  type        = string
  default     = "AWS"

  validation {
    condition     = var.vendor_name == "AWS" ? true : false
    error_message = "The vendor_name of the rules to apply to the WAF. This deployment currently only supports AWS-managed rules, so the vendor_name value must be AWS."
  }
}

variable "enable_sampled_requests" {
  description = "Use to enable sampled logging in the WAF account. Useful for short-term WAF monitoring of application usage and abuse."
  type        = bool
  default     = true
}

## Enable Cloudwatch logging
variable "enable_cloudwatch" {
  description = "Use to enable cloudwatch logging in the WAF account. Useful for long-term WAF monitoring of application usage and abuse."
  type        = bool
  default     = false
}

variable "log_to_s3" {
  description = "Use to enable WAF logging to an S3 bucket. NOTE: Bucket hane MUST begin with aws-waf-logs- or this will fail."
  type        = bool
  default     = false
}

variable "cloudwatch_log_group_name" {
  description = "The name of the Cloudwatch log group to use for creating dashboards and monitoring WAF logs"
  type        = string
  default     = "kasm-waf-log-group"
}

# AWS Managed Rule Sets with default settings
variable "aws_managed_rule_sets_with_defaults" {
  description = "AWS managed rule sets to use default settings"
  type = list(object({
    name      = string
    rule_name = string
    priority  = number # Used by AWS to provide inspection order for ACL rules
  }))
  default = [{
    name      = "AWS-AWSManagedRulesAmazonIpReputationList"
    rule_name = "AWSManagedRulesAmazonIpReputationList"
    priority  = 0
    }, {
    name      = "AWS-AWSManagedRulesLinuxRuleSet"
    rule_name = "AWSManagedRulesLinuxRuleSet"
    priority  = 1
    }, {
    name      = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    rule_name = "AWSManagedRulesLinuxRuleSet"
    priority  = 2
    }, {
    name      = "AWS-AWSManagedRulesCommonRuleSet"
    rule_name = "AWSManagedRulesLinuxRuleSet"
    priority  = 3
    }, {
    name      = "AWS-AWSManagedRulesAdminProtectionRuleSet"
    rule_name = "AWSManagedRulesLinuxRuleSet"
    priority  = 4
    }, {
    name      = "AWS-AWSManagedRulesSQLiRuleSet"
    rule_name = "AWSManagedRulesLinuxRuleSet"
    priority  = 5
    }
  ]
}

## Kasm Admin rule group and IP set used for WAF bypass for Kasm administrative IPs and functions
variable "kasm_ip_set_config" {
  description = "Configuration values for Kasm IP Set to apply to the Kasm management rule for Administrative IP bypass"
  type = map(object({
    name        = string
    ip_version  = string
    description = optional(string)
  }))
  default = {
    ip_set = {
      name        = "Kasm-Management-WAF-Bypass-IPs"
      description = "Kasm SaaS administration IP address to allow to bypass the WAF for management functions"
      ip_version  = "IPV4"
    }
  }
}

variable "kasm_rule_group_config" {
  description = "The Kasm WAF bypass rule group configuration settings"
  type = map(object({
    name        = string
    description = string
    capacity    = number
    rule_name   = string
    priority    = number
  }))
  default = {
    rule_group = {
      name        = "KASM-KasmWAFBypassRuleGroup"
      description = "WAF bypass rule for Kasm SaaS administration"
      capacity    = 50
      rule_name   = "KasmWAFBypassRuleGroup"
      priority    = 0
    }
  }
}

## AWS ATP Rule settings
variable "aws_managed_rule_atp" {
  description = "Kasm settings for AWS-managed Advanced Threat Protection (ATP) rule"
  type = map(object({
    name         = string
    priority     = number
    rule_name    = string
    vendor       = string
    login_path   = string
    payload_type = string
    username     = string
    password     = string
  }))
  default = {
    atp_rule = {
      name         = "AWS-AWSManagedRulesATPRuleSet"
      priority     = 2
      rule_name    = "AWSManagedRulesATPRuleSet"
      vendor       = "AWS"
      login_path   = "/api/authenticate"
      payload_type = "JSON"
      username     = "/username"
      password     = "/password"
    }
  }
}

## AWS Bot Rule settings
variable "aws_managed_rule_bots" {
  description = "Settings for AWS-managed Bot protection rule"
  type = map(object({
    name             = string
    priority         = number
    rule_name        = string
    inspection_level = string
  }))
  default = {
    bots = {
      name             = "AWS-AWSManagedRulesBotControlRuleSet"
      priority         = 3
      rule_name        = "AWSManagedRulesBotControlRuleSet"
      inspection_level = "COMMON"
    }
  }
}
