/*
 * Create a custom IP set for management or other IP groupings to use for rules
 */
resource "aws_wafv2_ip_set" "bypass_ips" {
  for_each = var.kasm_ip_set_config

  name               = each.value.name
  description        = each.value.description
  scope              = var.waf_scope
  ip_address_version = each.value.ip_version
  addresses          = var.admin_bypass_ips
}

/*
 * Create custom WAF rule group for Kasm-specific rules
 */
resource "aws_wafv2_rule_group" "management_bypass" {
  for_each = var.kasm_rule_group_config

  name        = each.key
  description = each.value.description
  scope       = var.waf_scope
  capacity    = each.value.capacity

  rule {
    name     = each.value.rule_name
    priority = each.value.priority

    action {
      allow {}
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.bypass_ips["ip_set"].arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = var.enable_cloudwatch
      sampled_requests_enabled   = var.enable_sampled_requests
      metric_name                = each.value.rule_name
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = var.enable_cloudwatch
    sampled_requests_enabled   = var.enable_sampled_requests
    metric_name                = each.value.name
  }
}

## Create the WAF name if only a prefix is provided
locals {
  waf_name = var.name == "" ? "${var.name_prefix}-WAF" : var.name
}

/*
 * Create WAF ACL rules
 */
resource "aws_wafv2_web_acl" "acls" {
  name        = local.waf_name
  description = var.description
  scope       = var.waf_scope

  default_action {
    allow {}
  }

  dynamic "rule" {
    for_each = var.kasm_rule_group_config

    content {
      name     = rule.value.rule_name
      priority = rule.value.priority

      override_action {
        none {}
      }

      statement {
        rule_group_reference_statement {
          arn = aws_wafv2_rule_group.management_bypass[(rule.key)].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = var.enable_cloudwatch
        sampled_requests_enabled   = var.enable_sampled_requests
        metric_name                = rule.value.rule_name
      }
    }
  }

  dynamic "rule" {
    for_each = var.aws_managed_rule_atp

    content {
      name     = rule.value.name
      priority = rule.value.priority

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.rule_name
          vendor_name = rule.value.vendor

          managed_rule_group_configs {
            login_path = rule.value.login_path
          }
          managed_rule_group_configs {
            payload_type = rule.value.payload_type
          }
          managed_rule_group_configs {
            username_field {
              identifier = rule.value.username
            }
          }
          managed_rule_group_configs {
            password_field {
              identifier = rule.value.password
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = var.enable_cloudwatch
        sampled_requests_enabled   = var.enable_sampled_requests
        metric_name                = rule.value.rule_name
      }
    }
  }

  dynamic "rule" {
    for_each = var.aws_managed_rule_bots

    content {
      name     = rule.value.name
      priority = rule.value.priority

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.rule_name
          vendor_name = var.vendor_name

          managed_rule_group_configs {
            aws_managed_rules_bot_control_rule_set {
              inspection_level = rule.value.inspection_level
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = var.enable_cloudwatch
        sampled_requests_enabled   = var.enable_sampled_requests
        metric_name                = rule.value.rule_name
      }
    }
  }

  dynamic "rule" {
    for_each = var.aws_managed_rule_sets_with_defaults

    content {
      name     = rule.value.name
      priority = rule.value.priority + 4

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.rule_name
          vendor_name = var.vendor_name
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = var.enable_cloudwatch
        sampled_requests_enabled   = var.enable_sampled_requests
        metric_name                = rule.value.rule_name
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = var.enable_cloudwatch
    sampled_requests_enabled   = var.enable_sampled_requests
    metric_name                = local.waf_name
  }
}

/*
 * Associate load balancers with WAF
 */
resource "aws_wafv2_web_acl_association" "lbs" {
  for_each = var.load_balancer_arns

  resource_arn = each.value
  web_acl_arn  = aws_wafv2_web_acl.acls.arn
}

/*
 * Configure WAF logging
 */
resource "aws_wafv2_web_acl_logging_configuration" "kasm_waf_logging" {
  count = var.enable_cloudwatch || var.log_to_s3 ? 1 : 0

  log_destination_configs = compact([var.waf_s3_bucket_arn, var.enable_cloudwatch ? aws_cloudwatch_log_group.this[0].arn : ""])
  resource_arn            = aws_wafv2_web_acl.acls.arn
}

/*
 * Setup CloudWatch Log group for WAF logs
 */
resource "aws_cloudwatch_log_group" "this" {
  count = var.enable_cloudwatch ? 1 : 0

  name = var.cloudwatch_log_group_name
}


