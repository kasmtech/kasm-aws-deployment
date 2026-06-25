# s3_persistent_profile

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
| [aws_s3_bucket.s3_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_intelligent_tiering_configuration.bucket_tiering](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_intelligent_tiering_configuration) | resource |
| [aws_s3_bucket_logging.logging](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_policy.s3_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.block_public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.encrypt_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.versioning](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bucket_base_name"></a> [bucket\_base\_name](#input\_bucket\_base\_name) | Optional: S3 Persistent profile bucket base name combined with random number to generate unique name | `string` | `""` | no |
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | Optional: S3 Persistent profile bucket name - Must be globally unique. | `string` | `""` | no |
| <a name="input_forward_logs"></a> [forward\_logs](#input\_forward\_logs) | Forward S3 bucket access and API logs to another S3 bucket | `bool` | `false` | no |
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | The Customer-managed KMS key to use to encrypt the S3 bucket | `string` | `""` | no |
| <a name="input_persistent_profile_s3_user_arn"></a> [persistent\_profile\_s3\_user\_arn](#input\_persistent\_profile\_s3\_user\_arn) | ARN of AWS user created for S3-based Kasm persistent profiles | `string` | n/a | yes |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Optional: Kasm project name to use in place of bucket\_base\_name for S3 bucket name prefix | `string` | `""` | no |
| <a name="input_s3_logging_bucket"></a> [s3\_logging\_bucket](#input\_s3\_logging\_bucket) | The S3 logging bucket where logs are to be forwarded | `string` | `""` | no |
| <a name="input_s3_target_log_folder"></a> [s3\_target\_log\_folder](#input\_s3\_target\_log\_folder) | The folder path where logs are to be stored | `string` | `"s3/persistent_profiles/"` | no |
| <a name="input_tiering_config"></a> [tiering\_config](#input\_tiering\_config) | S3 Bucket auto-tiering configuration settings | <pre>list(object({<br>    access_tier = string<br>    days        = number<br>  }))</pre> | <pre>[<br>  {<br>    "access_tier": "ARCHIVE_ACCESS",<br>    "days": 120<br>  },<br>  {<br>    "access_tier": "DEEP_ARCHIVE_ACCESS",<br>    "days": 180<br>  }<br>]</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | S3 Persistent Profile bucket arn |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->


