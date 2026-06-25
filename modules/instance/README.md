# instance

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
| [aws_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_instance_settings"></a> [instance\_settings](#input\_instance\_settings) | An object containing AWS Launch template instance settings | <pre>object({<br>    ami_id             = string<br>    instance_type      = string<br>    ssh_key_name       = string<br>    security_group_ids = list(string)<br>    subnet_id          = string<br>    is_public          = optional(bool)<br>    name               = optional(string)<br>    description        = optional(string)<br>  })</pre> | n/a | yes |
| <a name="input_metadata"></a> [metadata](#input\_metadata) | Instance metadata options. Default values configure strict IMDSv2 for security. | <pre>object({<br>    endpoint  = optional(string)<br>    tokens    = optional(string)<br>    hop_limit = optional(number)<br>    tags      = optional(string)<br>  })</pre> | n/a | yes |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | The deployment project name to use with name/description values if not provided | `string` | `""` | no |
| <a name="input_root_device"></a> [root\_device](#input\_root\_device) | Root Boot disk configuration settings | <pre>list(object({<br>    delete       = optional(bool)<br>    encrypt_disk = optional(bool)<br>    kms_key_arn  = optional(string)<br>    hdd_size     = optional(number)<br>    volume_type  = optional(string)<br>  }))</pre> | n/a | yes |
| <a name="input_system_role"></a> [system\_role](#input\_system\_role) | The AWS Instance server role to use in the instance name and description if neither is provided in the instance\_settings or group\_settings | `string` | `""` | no |
| <a name="input_user_data"></a> [user\_data](#input\_user\_data) | AWS Instance Base64 encoded User Data startup script | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_private_ip"></a> [private\_ip](#output\_private\_ip) | Instance private IP address |
| <a name="output_public_ip"></a> [public\_ip](#output\_public\_ip) | Instance public IP address (if assigned) |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->


