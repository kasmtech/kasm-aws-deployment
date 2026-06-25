variable "sg_rules" {
  description = ""
  type = list(object({
    sgid                  = string
    sg_name               = string
    enable_default_egress = optional(bool, false)
    rules = list(object({
      key         = string
      description = optional(string)
      from_port   = optional(number)
      protocol    = optional(string)
      to_port     = optional(number)
      type        = optional(string)
      cidr_blocks = optional(list(string), [""])
      source_sgid = optional(string, "")
    }))
  }))
}