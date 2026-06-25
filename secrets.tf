#########################################################################################
##                                                                                     ##
##                           Kasm Secrets & Credentials                                ##
##                                                                                     ##
##  Generates Kasm passwords/tokens, shapes them into per-item payloads, and writes    ##
##  them to AWS Secrets Manager. Secrets live in var.primary_region. SM secret names   ##
##  follow the documented `<standard_customer_name>/<slug>` scheme and are stable      ##
##  across re-applies.                                                                 ##
##                                                                                     ##
#########################################################################################

locals {
  # nonsensitive(): the result members are hardcoded role-name literals, not derived from the
  # password values, but conditionals that read sensitive vars produce sensitive results.
  passwords_to_create = nonsensitive(var.generate_passwords ? compact([
    var.kasm_admin_password == "" ? "admin" : "",
    var.kasm_user_password == "" ? "user" : "",
    var.kasm_database_password == "" ? "db" : "",
    var.kasm_service_token == "" ? "service" : "",
    var.kasm_manager_token == "" ? "manager" : "",
    var.generate_db_preseed && var.kasm_siteadmin_password == "" ? "siteadmin" : "",
    var.generate_db_preseed && var.kasm_workspaceadmin_password == "" ? "workspaceadmin" : "",
    var.generate_db_preseed && var.kasm_system_password == "" ? "system" : ""
  ]) : [])

  admin_password          = var.kasm_admin_password == "" ? module.passwords["admin"].password : var.kasm_admin_password
  user_password           = var.kasm_user_password == "" ? module.passwords["user"].password : var.kasm_user_password
  database_password       = var.kasm_database_password == "" ? module.passwords["db"].password : var.kasm_database_password
  service_token           = var.kasm_service_token == "" ? module.passwords["service"].password : var.kasm_service_token
  manager_token           = var.kasm_manager_token == "" ? module.passwords["manager"].password : var.kasm_manager_token
  siteadmin_password      = var.generate_db_preseed && var.kasm_siteadmin_password == "" ? module.passwords["siteadmin"].password : var.kasm_siteadmin_password
  workspaceadmin_password = var.generate_db_preseed && var.kasm_workspaceadmin_password == "" ? module.passwords["workspaceadmin"].password : var.kasm_workspaceadmin_password
  system_password         = var.generate_db_preseed && var.kasm_system_password == "" ? module.passwords["system"].password : var.kasm_system_password

  ## Credential groupings consumed by the AWS Secrets Manager payloads below
  ## (and, in the parent wrapper, by the 1Password uploads via module outputs).
  ## Relocated from the former kasm_internal.tf during the parent/child split.
  system_credentials_to_upload = {
    database = local.database_password,
    service  = local.service_token,
    manager  = local.manager_token,
  }

  user_credentials_to_upload = {
    admin          = local.admin_password,
    siteadmin      = local.siteadmin_password,
    system         = local.system_password,
    workspaceadmin = local.workspaceadmin_password,
    user           = local.user_password,
  }

  ## AWS Secrets Manager payloads. Each entry maps an SM secret name to a
  ## JSON-native payload (nested maps, native arrays — no section/field/type
  ## metadata). Same credential and config values 1Password sees, shaped for
  ## consumers that read SM directly.

  aws_sm_autoscale_configs = {
    for region in local.all_regions :
    "${local.standard_customer_name}/${region}/autoscale-config" => {
      region = region
      agent = {
        ami_id             = data.aws_ami.instance[region].id
        instance_type      = var.agent_instance_type
        iam_role           = local.kasminit_role_name
        security_group_ids = [module.vpc[region].security_group_ids["agent-security-group"]]
        subnet_ids         = local.public_agent_subnet_ids[region]
        ssh_public_key     = local.agent_ssh_public_key
      }
      tags = {
        Deployment_type = var.deployment_type
        Project_name    = local.standard_customer_name
        Deployed_by     = "Kasm Autoscale"
        Region          = region
      }
      startup_script = local.autoscale_agent_userdata[region]
    }
  }

  aws_sm_ssh_keys = {
    "${local.standard_customer_name}/ssh-keys" = {
      for key, value in module.ssh_keys :
      key => key == "agent" ? {
        public_key      = value.ssh_key_info.public_key
        private_key     = value.ssh_key_info.private_key
        pem_public_key  = module.ssh_keys["agent"].ssh_key_info_pem.public_key
        pem_private_key = module.ssh_keys["agent"].ssh_key_info_pem.private_key
        } : {
        public_key  = value.ssh_key_info.public_key
        private_key = value.ssh_key_info.private_key
      }
    }
  }

  aws_sm_autoscale_user = {
    "${local.standard_customer_name}/autoscale-user" = {
      access_key_id     = module.iam_users["${local.standard_customer_name}-vm-autoscale-user"].iam_access_key_id
      secret_access_key = module.iam_users["${local.standard_customer_name}-vm-autoscale-user"].iam_access_key_secret
    }
  }

  aws_sm_system_creds = {
    "${local.standard_customer_name}/other-credential" = local.system_credentials_to_upload
  }

  aws_sm_user_creds = {
    for key, value in local.user_credentials_to_upload :
    "${local.standard_customer_name}/${key}-credential" => merge(
      {
        username = "${key}@kasm.local"
        password = value
      },
      key == "system" && var.kasm_system_otp_code != "" ? {
        otp_uri = "otpauth://totp/${var.kasm_domain_name}:${key}@kasm.local?secret=${var.kasm_system_otp_code}&issuer=${var.kasm_domain_name}&period=30&digits=6&algorithm=SHA1"
      } : {}
    )
  }
}

## Generate Kasm passwords/tokens for any role whose corresponding var.kasm_*_password
## input was left empty (and var.generate_passwords = true).
module "passwords" {
  source   = "./modules/passwords"
  for_each = toset(local.passwords_to_create)
}

## Per-region autoscale configuration payloads.
module "aws_sm_autoscale_configs" {
  source   = "./modules/aws_sm_mirror"
  for_each = local.aws_sm_autoscale_configs

  secret_name             = each.key
  secret_description      = "${title(local.standard_customer_name)} autoscale configuration for ${split("/", each.key)[1]}."
  secret_payload          = each.value
  recovery_window_in_days = var.aws_sm_recovery_window_in_days

  providers = {
    aws = aws.regions[var.primary_region]
  }
}

## Bastion / agent / mgmt SSH key pairs.
module "aws_sm_ssh_keys" {
  source   = "./modules/aws_sm_mirror"
  for_each = local.aws_sm_ssh_keys

  secret_name             = each.key
  secret_description      = "${title(local.standard_customer_name)} SSH key pairs (per role)."
  secret_payload          = each.value
  recovery_window_in_days = var.aws_sm_recovery_window_in_days

  providers = {
    aws = aws.regions[var.primary_region]
  }
}

## IAM access key pair for the autoscale user.
module "aws_sm_autoscale_user" {
  source   = "./modules/aws_sm_mirror"
  for_each = local.aws_sm_autoscale_user

  secret_name             = each.key
  secret_description      = "${title(local.standard_customer_name)} autoscale IAM user access keys."
  secret_payload          = each.value
  recovery_window_in_days = var.aws_sm_recovery_window_in_days

  providers = {
    aws = aws.regions[var.primary_region]
  }
}

## System-level credentials (database, service, manager).
module "aws_sm_system_creds" {
  source   = "./modules/aws_sm_mirror"
  for_each = local.aws_sm_system_creds

  secret_name             = each.key
  secret_description      = "${title(local.standard_customer_name)} system credentials (database, service, manager tokens)."
  secret_payload          = each.value
  recovery_window_in_days = var.aws_sm_recovery_window_in_days

  providers = {
    aws = aws.regions[var.primary_region]
  }
}

## Kasm UI user credentials (admin / siteadmin / system / user / workspaceadmin).
module "aws_sm_user_creds" {
  source   = "./modules/aws_sm_mirror"
  for_each = local.aws_sm_user_creds

  secret_name             = each.key
  secret_description      = "${title(local.standard_customer_name)} Kasm UI user credentials."
  secret_payload          = each.value
  recovery_window_in_days = var.aws_sm_recovery_window_in_days

  providers = {
    aws = aws.regions[var.primary_region]
  }
}
