# efs

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
| [aws_efs_backup_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_backup_policy) | resource |
| [aws_efs_file_system.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_file_system) | resource |
| [aws_efs_mount_target.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_mount_target) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_efs_share_name"></a> [efs\_share\_name](#input\_efs\_share\_name) | Name to use for NFS share | `string` | n/a | yes |
| <a name="input_is_encrypted"></a> [is\_encrypted](#input\_is\_encrypted) | Used to encrypt the NFS filesystem. If set to true, the kms\_key\_id must also be set appropriately | `bool` | `true` | no |
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | KMS key ID to use for NFS filesystem encryption. Must be set if is\_encrypted is set to true. | `string` | `""` | no |
| <a name="input_mount_target_settings"></a> [mount\_target\_settings](#input\_mount\_target\_settings) | The mount target settings | <pre>map(object({<br>    subnet_id          = string<br>    security_group_ids = list(string)<br>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_nfs_url"></a> [nfs\_url](#output\_nfs\_url) | The NFS DNS name to use when attaching Kasm agents |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->


