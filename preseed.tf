#########################################################################################
##                                                                                     ##
##  Kasm DB preseed generation. Produces the `default_properties.yaml` that seeds the  ##
##  Kasm database (Site Admin / Workspace Admin groups + permissions, and any extra    ##
##  API accounts) and, unless var.upload_db_preseed = false, uploads it to the DB     ##
##  backup bucket where the database (VM userdata or remote DB init) reads it.         ##
##                                                                                     ##
##  Wrappers that store the file themselves set upload_db_preseed = false and read    ##
##  the `default_properties_yaml` output.                                              ##
##                                                                                     ##
#########################################################################################

locals {
  ## Passwords baked into the preseed. API account passwords are generated for
  ## each entry in var.api_preseeds (empty by default).
  kasm_passwords = {
    site_admin      = local.siteadmin_password
    workspace_admin = local.workspaceadmin_password
    system_admin    = local.system_password
  }

  ## Read by the VM DB userdata (BACKUP_BUCKET_DIR_NAME + CUSTOM_PROPERTIES_FILENAME)
  ## and by modules/remote_db_init (preseed_s3_key); keep the three in step.
  db_preseed_s3_key = "aws/${local.standard_customer_name}/${var.kasm_version}-default_properties.yaml"

  preseed_api_configs = {
    for api, config in var.api_preseeds : api => merge(config, { password = module.api_passwords[api].password })
  }
}

## One generated password per extra API account requested by the caller.
module "api_passwords" {
  source   = "./modules/passwords"
  for_each = toset(keys(var.api_preseeds))
}

## Renders default_properties.yaml. Gated on var.generate_db_preseed.
module "custom_properties" {
  source = "./modules/kasm_config"
  count  = var.generate_db_preseed ? 1 : 0

  alembic_version = var.alembic_version
  domain_name     = var.kasm_domain_name
  passwords       = local.kasm_passwords
  api_configs     = local.preseed_api_configs
}

## Store the rendered preseed where the database picks it up at first boot.
resource "aws_s3_object" "db_preseed" {
  count = var.generate_db_preseed && var.upload_db_preseed ? 1 : 0

  bucket  = var.db_backup_bucket_name
  key     = local.db_preseed_s3_key
  content = module.custom_properties[0].default_properties_yaml

  provider = aws.regions[var.primary_region]
}
