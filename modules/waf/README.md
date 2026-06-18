# waf

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
Create a custom IP set for management or other IP groupings to use for rules

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.38.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_wafv2_ip_set.bypass_ips](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_ip_set) | resource |
| [aws_wafv2_rule_group.management_bypass](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_rule_group) | resource |
| [aws_wafv2_web_acl.acls](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |
| [aws_wafv2_web_acl_association.lbs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_association) | resource |
| [aws_wafv2_web_acl_logging_configuration.kasm_waf_logging](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_logging_configuration) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_bypass_ips"></a> [admin\_bypass\_ips](#input\_admin\_bypass\_ips) | Rule to allow designated IP addressess to bypass the WAF for administrative functions | `list(string)` | n/a | yes |
| <a name="input_aws_managed_rule_atp"></a> [aws\_managed\_rule\_atp](#input\_aws\_managed\_rule\_atp) | Kasm settings for AWS-managed Advanced Threat Protection (ATP) rule | <pre>map(object({<br>    name         = string<br>    priority     = number<br>    rule_name    = string<br>    vendor       = string<br>    login_path   = string<br>    payload_type = string<br>    username     = string<br>    password     = string<br>  }))</pre> | <pre>{<br>  "atp_rule": {<br>    "login_path": "/api/authenticate",<br>    "name": "AWS-AWSManagedRulesATPRuleSet",<br>    "password": "/password",<br>    "payload_type": "JSON",<br>    "priority": 2,<br>    "rule_name": "AWSManagedRulesATPRuleSet",<br>    "username": "/username",<br>    "vendor": "AWS"<br>  }<br>}</pre> | no |
| <a name="input_aws_managed_rule_bots"></a> [aws\_managed\_rule\_bots](#input\_aws\_managed\_rule\_bots) | Settings for AWS-managed Bot protection rule | <pre>map(object({<br>    name             = string<br>    priority         = number<br>    rule_name        = string<br>    inspection_level = string<br>  }))</pre> | <pre>{<br>  "bots": {<br>    "inspection_level": "COMMON",<br>    "name": "AWS-AWSManagedRulesBotControlRuleSet",<br>    "priority": 3,<br>    "rule_name": "AWSManagedRulesBotControlRuleSet"<br>  }<br>}</pre> | no |
| <a name="input_aws_managed_rule_sets_with_defaults"></a> [aws\_managed\_rule\_sets\_with\_defaults](#input\_aws\_managed\_rule\_sets\_with\_defaults) | AWS managed rule sets to use default settings | <pre>list(object({<br>    name      = string<br>    rule_name = string<br>    priority  = number # Used by AWS to provide inspection order for ACL rules<br>  }))</pre> | <pre>[<br>  {<br>    "name": "AWS-AWSManagedRulesAmazonIpReputationList",<br>    "priority": 0,<br>    "rule_name": "AWSManagedRulesAmazonIpReputationList"<br>  },<br>  {<br>    "name": "AWS-AWSManagedRulesLinuxRuleSet",<br>    "priority": 1,<br>    "rule_name": "AWSManagedRulesLinuxRuleSet"<br>  },<br>  {<br>    "name": "AWS-AWSManagedRulesKnownBadInputsRuleSet",<br>    "priority": 2,<br>    "rule_name": "AWSManagedRulesLinuxRuleSet"<br>  },<br>  {<br>    "name": "AWS-AWSManagedRulesCommonRuleSet",<br>    "priority": 3,<br>    "rule_name": "AWSManagedRulesLinuxRuleSet"<br>  },<br>  {<br>    "name": "AWS-AWSManagedRulesAdminProtectionRuleSet",<br>    "priority": 4,<br>    "rule_name": "AWSManagedRulesLinuxRuleSet"<br>  },<br>  {<br>    "name": "AWS-AWSManagedRulesSQLiRuleSet",<br>    "priority": 5,<br>    "rule_name": "AWSManagedRulesLinuxRuleSet"<br>  }<br>]</pre> | no |
| <a name="input_cloudwatch_log_group_name"></a> [cloudwatch\_log\_group\_name](#input\_cloudwatch\_log\_group\_name) | The name of the Cloudwatch log group to use for creating dashboards and monitoring WAF logs | `string` | `"kasm-waf-log-group"` | no |
| <a name="input_description"></a> [description](#input\_description) | Description for the WAF ACL resource | `string` | `""` | no |
| <a name="input_enable_cloudwatch"></a> [enable\_cloudwatch](#input\_enable\_cloudwatch) | Use to enable cloudwatch logging in the WAF account. Useful for long-term WAF monitoring of application usage and abuse. | `bool` | `false` | no |
| <a name="input_enable_sampled_requests"></a> [enable\_sampled\_requests](#input\_enable\_sampled\_requests) | Use to enable sampled logging in the WAF account. Useful for short-term WAF monitoring of application usage and abuse. | `bool` | `true` | no |
| <a name="input_kasm_ip_set_config"></a> [kasm\_ip\_set\_config](#input\_kasm\_ip\_set\_config) | Configuration values for Kasm IP Set to apply to the Kasm management rule for Administrative IP bypass | <pre>map(object({<br>    name        = string<br>    ip_version  = string<br>    description = optional(string)<br>  }))</pre> | <pre>{<br>  "ip_set": {<br>    "description": "Kasm SaaS administration IP address to allow to bypass the WAF for management functions",<br>    "ip_version": "IPV4",<br>    "name": "Kasm-Management-WAF-Bypass-IPs"<br>  }<br>}</pre> | no |
| <a name="input_kasm_rule_group_config"></a> [kasm\_rule\_group\_config](#input\_kasm\_rule\_group\_config) | The Kasm WAF bypass rule group configuration settings | <pre>map(object({<br>    name        = string<br>    description = string<br>    capacity    = number<br>    rule_name   = string<br>    priority    = number<br>  }))</pre> | <pre>{<br>  "rule_group": {<br>    "capacity": 50,<br>    "description": "WAF bypass rule for Kasm SaaS administration",<br>    "name": "KASM-KasmWAFBypassRuleGroup",<br>    "priority": 0,<br>    "rule_name": "KasmWAFBypassRuleGroup"<br>  }<br>}</pre> | no |
| <a name="input_load_balancer_arns"></a> [load\_balancer\_arns](#input\_load\_balancer\_arns) | List of management region Public Load Balancer ARNs | `list(string)` | n/a | yes |
| <a name="input_log_to_s3"></a> [log\_to\_s3](#input\_log\_to\_s3) | Use to enable WAF logging to an S3 bucket. NOTE: Bucket hane MUST begin with aws-waf-logs- or this will fail. | `bool` | `false` | no |
| <a name="input_name"></a> [name](#input\_name) | Name for the WAF ACL resource. If unset, the name prefix is used to generate a generic name. | `string` | `""` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Kasm project name to use for label and name values | `string` | `""` | no |
| <a name="input_vendor_name"></a> [vendor\_name](#input\_vendor\_name) | The Vendor name to use for the default rules | `string` | `"AWS"` | no |
| <a name="input_waf_s3_bucket_arn"></a> [waf\_s3\_bucket\_arn](#input\_waf\_s3\_bucket\_arn) | S3 log bucket ARN where Kasm WAF logs should be sent | `string` | n/a | yes |
| <a name="input_waf_scope"></a> [waf\_scope](#input\_waf\_scope) | Scope to use for this WAF deployment | `string` | `"REGIONAL"` | no |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
