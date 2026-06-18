# autoscale_notification

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
| [aws_autoscaling_notification.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_notification) | resource |
| [aws_sns_topic.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_subscription.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_autoscale_groups"></a> [autoscale\_groups](#input\_autoscale\_groups) | A list of Autoscale groups to create an SNS notification for | `list(string)` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | SNS notification topic name | `string` | n/a | yes |
| <a name="input_notifications"></a> [notifications](#input\_notifications) | List of AWS events to generate notifications from | `list(string)` | <pre>[<br>  "autoscaling:EC2_INSTANCE_TERMINATE",<br>  "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",<br>  "autoscaling:EC2_INSTANCE_TERMINATE_ERROR"<br>]</pre> | no |
| <a name="input_sns_email"></a> [sns\_email](#input\_sns\_email) | Email address to receive SNS notifications | `string` | n/a | yes |
| <a name="input_sns_kms_key_id"></a> [sns\_kms\_key\_id](#input\_sns\_kms\_key\_id) | KMS Key to encrypt the SNS topic data | `string` | `""` | no |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

