# autoscale

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.43.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_autoscaling_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_attachment) | resource |
| [aws_autoscaling_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_autoscaling_policy.kasm_autoscale_cpu_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_policy) | resource |
| [aws_launch_template.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_iam_instance_profile.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_instance_profile) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_instance_profile_name"></a> [instance\_profile\_name](#input\_instance\_profile\_name) | The instance profile name to use | `string` | `""` | no |
| <a name="input_instance_settings"></a> [instance\_settings](#input\_instance\_settings) | An object containing AWS Launch template instance settings | <pre>object({<br>    ami_id             = string<br>    instance_type      = string<br>    ssh_key_name       = string<br>    security_group_ids = list(string)<br>    name               = string<br>  })</pre> | n/a | yes |
| <a name="input_metadata"></a> [metadata](#input\_metadata) | Instance metadata options. Default values configure strict IMDSv2 for security. | <pre>object({<br>    endpoint  = optional(string)<br>    tokens    = optional(string)<br>    hop_limit = optional(number)<br>    tags      = optional(string)<br>  })</pre> | n/a | yes |
| <a name="input_root_device"></a> [root\_device](#input\_root\_device) | Root Boot disk configuration settings | <pre>list(object({<br>    delete       = optional(bool)<br>    encrypt_disk = optional(bool)<br>    kms_key_arn  = optional(string)<br>    hdd_size     = optional(number)<br>    volume_type  = optional(string)<br>  }))</pre> | n/a | yes |
| <a name="input_scale_group_settings"></a> [scale\_group\_settings](#input\_scale\_group\_settings) | An object containing AWS Autoscale group configuration settings | <pre>object({<br>    name                = string<br>    description         = optional(string)<br>    min_size            = number<br>    max_size            = number<br>    subnet_ids          = list(string)<br>    health_check_period = number<br>    cool_down_period    = number<br>    health_check_type   = string<br>    min_health_percent  = number<br>  })</pre> | n/a | yes |
| <a name="input_scale_policy"></a> [scale\_policy](#input\_scale\_policy) | An object containing the Autoscale CPU Scaling policy settings | <pre>object({<br>    name        = optional(string)<br>    policy_type = string<br>    deploy_time = number<br>    metric_type = string<br>    target_load = number<br>  })</pre> | <pre>{<br>  "deploy_time": 600,<br>  "metric_type": "ASGAverageCPUUtilization",<br>  "policy_type": "TargetTrackingScaling",<br>  "target_load": 60<br>}</pre> | no |
| <a name="input_system_role"></a> [system\_role](#input\_system\_role) | The AWS Instance server role to use in the instance name and description if neither is provided in the instance\_settings or group\_settings | `string` | `""` | no |
| <a name="input_target_group_arns"></a> [target\_group\_arns](#input\_target\_group\_arns) | A list of AWS Load Balancer Target Group ARNs to attach to the autoscale group | `list(string)` | `[]` | no |
| <a name="input_user_data"></a> [user\_data](#input\_user\_data) | AWS Instance Base64 encoded User Data startup script | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_asg_arn"></a> [asg\_arn](#output\_asg\_arn) | The ARN of the Autoscale group |
| <a name="output_asg_name"></a> [asg\_name](#output\_asg\_name) | The name of the newly created Autoscale group |
| <a name="output_instance_template_arn"></a> [instance\_template\_arn](#output\_instance\_template\_arn) | The ARN of the Instance template |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

