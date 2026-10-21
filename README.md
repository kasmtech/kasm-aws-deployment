# kasm-aws-deployment

OpenTofu module that deploys [Kasm Workspaces](https://kasmweb.com) on AWS: a VPC per
region, public and private Application Load Balancers (optionally behind AWS WAF), a
Kasm database (Aurora PostgreSQL Global Database or a single EC2 instance), webapp
autoscaling groups, optional connection proxies, Route 53 records and ACM certificates,
and the IAM, Secrets Manager and autoscale configuration Kasm needs to scale agents.

## Requirements

- OpenTofu `~> 1.11`
- AWS provider `~> 6.0`
- An S3 bucket for OpenTofu state
- An S3 bucket in the primary region for DB backups and the generated DB preseed
  (`db_backup_bucket_name`); the module grants access to it but does not create it
- Either a Route 53 hosted zone for the Kasm domain or a parent zone to delegate from
  (`create_route53_zone` / `parent_dns_zone_name`)

## Usage

This repository can be deployed on its own as a root module, or called as a module
from your own configuration.

### Standalone

Clone the repository, copy the example inputs and fill them in:

```bash
cp terraform.tfvars.example terraform.tfvars
tofu init
tofu plan
tofu apply
```

`terraform.tfvars.example` lists the required inputs and the common optional ones;
everything else has a working default. State goes to the S3 backend configured from
`backend_bucket` / `backend_bucket_region`, under `aws/<customer_name>/terraform.tfstate`.
Passwords left empty are generated (`generate_passwords = true`), and the DB preseed is
uploaded to `db_backup_bucket_name` for the database to pick up on first boot.

### As a module

```hcl
module "kasm" {
  source = "<registry or git source for this module>"

  customer_name                = "example"
  kasm_domain_name             = "kasm.example.com"
  primary_region               = "us-east-1"
  secondary_regions            = []
  backend_bucket               = "example-tofu-state"
  db_backup_bucket_name        = "example-kasm-db-backups"
  number_of_availability_zones = 3
  deploy_waf                   = true
  waf_bypass_ips               = ["198.51.100.10/32"]

  aws_to_kasm_zone_map = {
    us-east-1 = "USA-(Virginia)"
  }
}
```

See `variables.tf` for every input and its default, and `outputs.tf` for what the module
returns (load balancer and target group identifiers, generated credentials, the rendered
DB preseed, and the autoscale configuration). The `backend "s3"` block only applies when
this repository is the root module; a calling configuration uses its own backend.

## Credentials

With `generate_passwords = true` (default) the module generates the Kasm passwords and
tokens and stores them in AWS Secrets Manager in the primary region. Credential outputs
are marked sensitive; OpenTofu state contains them, so keep state encrypted and
access-restricted.

## Customising instance bootstrap

Each role's userdata is rendered with `templatefile()` from `userdata_dir` (defaults to
the scripts bundled in `userdata/`). To supply your own scripts:

- `userdata_dir` and the `*_userdata_file` inputs select the scripts.
- `userdata_template_vars` adds template variables your scripts need that this module
  does not define.
- `kasminit_secret_arns` / `kasminit_kms_key_arns` let the instance roles read additional
  Secrets Manager secrets at boot. The deployment's own system-credentials secret is
  always readable.

## DB preseed

With `generate_db_preseed = true` (default) the module renders a `default_properties.yaml`
that seeds the Kasm database and uploads it to
`s3://<db_backup_bucket_name>/aws/<customer>/<kasm_version>-default_properties.yaml`.
Set `upload_db_preseed = false` if your configuration stores it elsewhere; the content is
available from the `default_properties_yaml` output. Extra Kasm API accounts can be seeded
through `api_preseeds`; a password is generated for each.
