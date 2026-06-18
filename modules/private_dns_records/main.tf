locals {
  # Convert `records` from list to map with unique keys
  recordsets = { for rs in var.records : try(rs.key, join(" ", compact(["${rs.name} ${rs.type}", try(rs.set_identifier, "")]))) => rs }
}

resource "aws_route53_record" "this" {
  for_each = { for k, v in local.recordsets : k => v }

  zone_id         = var.zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = lookup(each.value, "ttl", null)
  records         = try(each.value.records, null)
  set_identifier  = lookup(each.value, "set_identifier", null)
  health_check_id = lookup(each.value, "health_check_id", null)

  dynamic "alias" {
    for_each = length(keys(lookup(each.value, "alias", {}))) == 0 ? [] : [true]

    content {
      name                   = each.value.alias.name
      zone_id                = var.zone_id
      evaluate_target_health = lookup(each.value.alias, "evaluate_target_health", false)
    }
  }
}

