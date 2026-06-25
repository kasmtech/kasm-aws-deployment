# kasm_config

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.44.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_s3_object.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_bucket) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | The bucket to upload the updated default properties file to | `string` | n/a | yes |
| <a name="input_file_name"></a> [file\_name](#input\_file\_name) | The name of the file to upload to the bucket | `string` | n/a | yes |
| <a name="input_site_admin_password"></a> [site\_admin\_password](#input\_site\_admin\_password) | The password to use for the `siteadmin@kasm.local` user | `string` | n/a | yes |
| <a name="input_system_admin_password"></a> [system\_admin\_password](#input\_system\_admin\_password) | The password to use for the `system@kasm.local` user | `string` | n/a | yes |
| <a name="input_workspace_admin_password"></a> [workspace\_admin\_password](#input\_workspace\_admin\_password) | The password to use for the `workspaceadmin@kasm.local` user | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
