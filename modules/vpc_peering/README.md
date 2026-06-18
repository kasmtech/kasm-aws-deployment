# vpc_peering

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws.accepter"></a> [aws.accepter](#provider\_aws.accepter) | 5.38.0 |
| <a name="provider_aws.requester"></a> [aws.requester](#provider\_aws.requester) | 5.38.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_route.accepter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.requester](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_vpc_peering_connection.requester](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_peering_connection) | resource |
| [aws_vpc_peering_connection_accepter.accepter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_peering_connection_accepter) | resource |
| [aws_caller_identity.accepter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_accepter_region"></a> [accepter\_region](#input\_accepter\_region) | The region of the Accepting VPC, or the Kasm Agent region | `string` | n/a | yes |
| <a name="input_accepter_routes"></a> [accepter\_routes](#input\_accepter\_routes) | VPC Accepter Routes to add to peering connections | <pre>list(object({<br>    route_table_id   = string<br>    destination_cidr = string<br>  }))</pre> | n/a | yes |
| <a name="input_accepter_vpc_id"></a> [accepter\_vpc\_id](#input\_accepter\_vpc\_id) | VPC ID of the accepter, or Kasm Management VPC | `string` | n/a | yes |
| <a name="input_requester_routes"></a> [requester\_routes](#input\_requester\_routes) | VPC Requester Routes to add to peering connections | <pre>list(object({<br>    route_table_id   = string<br>    destination_cidr = string<br>  }))</pre> | n/a | yes |
| <a name="input_requester_vpc_id"></a> [requester\_vpc\_id](#input\_requester\_vpc\_id) | VPC ID of the requester, or Kasm Agent VPC | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_accepter_peer_id"></a> [accepter\_peer\_id](#output\_accepter\_peer\_id) | The VPC peering ID of the accepter |
| <a name="output_requester_peer_id"></a> [requester\_peer\_id](#output\_requester\_peer\_id) | The VPC peering ID of the requester |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
