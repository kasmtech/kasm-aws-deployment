variable "certificate_arn" {
  description = "The ARN of the AWS ACM cert to attach to the HTTPS listener"
  type        = string
}

variable "default_target_group" {
  description = "The defauly target group to forward traffic to"
  type        = string
  default     = ""

  validation {
    condition     = var.default_target_group == "" || contains(keys(var.target_groups_new), var.default_target_group)
    error_message = "The default targetr group must either be not set or be listed in target_groups variable"
  }
}

variable "name" {
  description = "Load balancer name"
  type        = string
}

variable "internal" {
  description = "Whether the load balancer is internal"
  type        = bool
  default     = false
}

variable "security_groups" {
  description = "Security groups to attach"
  type        = list(string)
  default     = []
}

variable "subnets" {
  description = "Subnet IDs for the load balancer"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID for target groups"
  type        = string
}

variable "access_logs" {
  description = "Access log settings"
  type        = map(any)
  default     = {}
}

variable "target_groups" {
  description = "Target group definitions"
  type        = list(any)
  default     = []
}

variable "http_tcp_listeners" {
  description = "HTTP/TCP listeners"
  type        = list(any)
  default     = []
}

variable "https_listeners" {
  description = "HTTPS listeners"
  type        = list(any)
  default     = []
}

variable "http_tcp_listener_rules" {
  description = "HTTP/TCP listener rules"
  type        = list(any)
  default     = []
}

variable "https_listener_rules" {
  description = "HTTPS listener rules keyed by a unique name"
  type = map(object({
    target_group = string
    host_headers = list(string)
  }))
  default = {}
}

variable "ssl_policy" {
  description = "The SSL policy to attach to the HTTPS listener"
  type        = string
  default     = null
}

variable "cors_allow_origin" {
  description = "Value for Access-Control-Allow-Origin response header on the HTTPS listener. Empty string leaves the header unset."
  type        = string
  default     = ""
}

variable "cors_allow_credentials" {
  description = "Value for Access-Control-Allow-Credentials response header on the HTTPS listener. Empty string leaves the header unset."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to the load balancer and target groups"
  type        = map(string)
  default     = {}
}


variable "target_groups_new" {
  description = "Target group definitions keyed by target group name"
  type = map(object({
    health_check = object({
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
    port             = optional(number, 443)
    protocol         = optional(string, "HTTPS")
    protocol_version = optional(string, "HTTP1")
    target_type      = optional(string, "instance")
  }))
  default = {}
}