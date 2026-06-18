# security_group_rules

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
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
| [aws_security_group_rule.cidr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cidr_rule"></a> [cidr\_rule](#input\_cidr\_rule) | Create a new rule with a list of CIDR blocks as the source/destination | `bool` | `false` | no |
| <a name="input_security_group_id"></a> [security\_group\_id](#input\_security\_group\_id) | ID of the security group | `string` | n/a | yes |
| <a name="input_sg_rule"></a> [sg\_rule](#input\_sg\_rule) | Create a new rule with a list of Security Group as the source | `bool` | `false` | no |
| <a name="input_source_cidr_rules"></a> [source\_cidr\_rules](#input\_source\_cidr\_rules) | List of objects of security group rules | <pre>list(object({<br>    sgid        = optional(string)<br>    type        = optional(string)<br>    protocol    = optional(string)<br>    from_port   = optional(number)<br>    to_port     = optional(number)<br>    description = optional(string)<br>    cidr_blocks = optional(list(string))<br>  }))</pre> | `[]` | no |
| <a name="input_source_sg_rules"></a> [source\_sg\_rules](#input\_source\_sg\_rules) | List of objects of security group rules | <pre>list(object({<br>    sgid        = optional(string)<br>    type        = optional(string)<br>    protocol    = optional(string)<br>    from_port   = optional(number)<br>    to_port     = optional(number)<br>    description = optional(string)<br>    source_sgid = optional(string)<br>  }))</pre> | `[]` | no |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
