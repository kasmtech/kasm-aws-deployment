locals {
  default_egress_rules = [
    for rule in var.sg_rules : {
      sgid        = rule.sgid
      sg_name     = rule.sg_name
      key         = "default-egress"
      description = "Default egress rule"
      type        = "egress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      cidr_blocks = ["0.0.0.0/0"]
      source_sgid = ""
    } if rule.enable_default_egress
  ]

  flattened_rules = concat(
    flatten([
      for rule in var.sg_rules : [
        for nested_rule in rule.rules : merge(
          {
            sgid    = rule.sgid
            sg_name = rule.sg_name
          },
          nested_rule
        )
      ]
    ]),
    local.default_egress_rules,
  )
}

resource "aws_security_group_rule" "this" {
  for_each = {
    for rule in local.flattened_rules : "${rule.sg_name}-${rule.key}" => rule
  }

  security_group_id = each.value.sgid

  description = each.value.description
  protocol    = each.value.protocol
  from_port   = each.value.from_port
  to_port     = each.value.to_port
  type        = each.value.type


  # One of these two must be set
  cidr_blocks              = each.value.cidr_blocks[0] == "" ? null : each.value.cidr_blocks
  source_security_group_id = each.value.source_sgid == "" ? null : each.value.source_sgid

}

