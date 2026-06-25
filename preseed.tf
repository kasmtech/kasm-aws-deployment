#########################################################################################
##                                                                                     ##
##  Kasm DB preseed generation. Produces the `default_properties.yaml` that seeds the  ##
##  Kasm database (Site Admin / Workspace Admin groups + permissions, and any extra    ##
##  API accounts). Relocated from the former kasm_internal.tf during the parent/child  ##
##  split: GENERATION is generic and lives here; the internal S3 UPLOAD of the result  ##
##  stays in the parent wrapper (it targets an internal bucket).                        ##
##                                                                                     ##
##  Standalone consumers read `module.custom_properties[0].default_properties_yaml`    ##
##  via the `default_properties_yaml` output.                                          ##
##                                                                                     ##
#########################################################################################

locals {
  ## Passwords baked into the preseed. API account passwords are generated for
  ## each entry in var.api_preseeds (empty by default — public-safe). The parent
  ## populates var.api_preseeds with internal API account names.
  kasm_passwords = merge(
    {
      site_admin      = local.siteadmin_password
      workspace_admin = local.workspaceadmin_password
      system_admin    = local.system_password
    },
    {
      for api, _ in var.api_preseeds : api => module.api_passwords[api].password
    }
  )
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
}
