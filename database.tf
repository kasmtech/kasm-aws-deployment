locals {
  allowed_db_connections = var.number_of_allowed_db_connections != null ? var.number_of_allowed_db_connections : 200 + length(var.secondary_regions) * 100
  backup_bucket_dir      = local.standard_customer_name
  db_private_hostname    = "database.${local.private_domain}"

  database_userdata = base64encode(
    templatefile("${path.module}/userdata/${var.db_userdata_file}", {
      ADDITIONAL_DATABASE_INSTALL_ARGS = var.database_additional_install_arguments
      BACKUP_BUCKET_DIR_NAME           = var.generate_db_preseed ? "aws/${local.standard_customer_name}/" : ""
      BLOCK_DEVICE                     = "nvme2n1"
      BUCKET_NAME                      = var.db_backup_bucket_name
      BUCKET_NAMESPACE                 = ""
      BUCKET_REGION                    = var.primary_region
      CUSTOMER_ENV                     = var.kasm_domain_name
      CUSTOMER_NAME                    = local.standard_customer_name
      CUSTOM_PROPERTIES_FILENAME       = var.generate_db_preseed ? "${var.kasm_version}-default_properties.yaml" : ""
      DB_CONNECTIONS                   = local.allowed_db_connections
      DB_INIT_OVERRIDE                 = "false"
      DEPLOYMENT_DOMAIN                = var.kasm_domain_name
      DEPLOYMENT_TYPE                  = var.deployment_type
      GRAFANA_FULL_METRICS             = "false"
      IMAGE_TYPE                       = var.image_type
      KASM_DOMAIN_NAME                 = var.kasm_domain_name
      KASM_DOWNLOAD_URL                = var.kasm_download_url
      KASM_ADMIN_PASS                  = local.admin_password
      KASM_DB_PASS                     = local.database_password
      KASM_MANAGER_TOKEN               = local.manager_token
      KASM_SERVICE_TOKEN               = local.service_token
      KASM_USER_PASS                   = local.user_password
      KASM_STIG_OVERRIDE               = var.kasm_stig_url
      KASM_VERSION                     = var.kasm_version
      PRIVATE_IP                       = local.db_private_hostname
      TELEPORT_VERSION                 = var.teleport_version
      WAZUH_JOIN_GROUP                 = var.wazuh_group

      # Vars consumed only by the consolidated db script. Originals ignore them; the
      # consolidated script gates pgconfigctl tuning and enhanced monitoring on these
      # being non-empty, so safe defaults are empty strings / "false".
      PGCONFIGCTL_SECRET_ID  = ""
      ENHANCED_DB_MONITORING = "false"
      DB_O11Y_PASSWORD       = ""
    })
  )
}

## VM-based database (default). Skipped when var.use_rds = true.
module "db_instance" {
  source = "./modules/database_instance"

  ami_id                = data.aws_ami.instance[var.primary_region].id
  availability_zone     = local.availability_zones[var.primary_region][0]
  customer_name         = local.standard_customer_name
  db_backup_bucket_name = var.db_backup_bucket_name
  db_instance_type      = var.db_instance_type
  kasminit_policy_arn   = aws_iam_policy.kasminit.arn
  resource_name_prefix  = local.resource_name_prefix
  security_group_ids    = [module.vpc[var.primary_region].security_group_ids["database-security-group"]]
  ssh_key_name          = local.mgmt_ssh_key_name
  subnet_id             = local.database_subnet_id
  user_data             = local.database_userdata

  lifecycle {
    enabled = !var.use_rds
  }

  providers = {
    aws = aws.regions[var.primary_region]
  }
}

#######################################
##                                   ##
##   Aurora Global Database (RDS)    ##
##                                   ##
#######################################

## Aurora Global cluster + primary writer (in primary_region).
module "rds_primary" {
  source = "./modules/rds-primary"

  name           = "${local.standard_customer_name}-aurora"
  primary_region = var.primary_region

  db_subnet_group_name   = module.vpc[var.primary_region].database_subnet_group
  vpc_security_group_ids = [module.vpc[var.primary_region].security_group_ids["database-security-group"]]

  engine                             = var.rds_engine
  engine_version                     = var.rds_engine_version
  database_name                      = var.rds_database_name
  master_username                    = var.rds_master_username
  master_password                    = local.database_password
  instance_class                     = var.rds_instance_class
  instances                          = var.rds_instances
  backup_retention_period            = var.rds_backup_retention_period
  deletion_protection                = var.rds_deletion_protection
  skip_final_snapshot                = var.rds_skip_final_snapshot
  serverlessv2_scaling_configuration = var.rds_serverlessv2_scaling_configuration

  lifecycle {
    enabled = var.use_rds
  }

  providers = {
    aws = aws.regions[var.primary_region]
  }
}

## AWS-managed alias/aws/rds key per DR region. Aurora Global Database
## requires an explicit KMS key for secondary clusters when the global cluster
## is encrypted — the AWS default key in each region works, but must be passed
## by ARN rather than implied.
data "aws_kms_key" "rds_secondary" {
  for_each = var.use_rds ? toset(var.rds_dr_regions) : toset([])

  key_id   = "alias/aws/rds"
  provider = aws.regions[each.key]
}

## Per-DR-region secondary clusters joined to the global cluster.
## With enable_write_forwarding=true, application writes against a secondary's
## endpoint are transparently forwarded to the global writer.
## Gated on var.use_rds via the for_each set; lifecycle.enabled cannot be combined with for_each.
module "rds_secondary" {
  source   = "./modules/rds-secondary"
  for_each = var.use_rds ? toset(var.rds_dr_regions) : toset([])

  name              = "${local.standard_customer_name}-aurora"
  region            = each.key
  source_region     = var.primary_region
  global_cluster_id = module.rds_primary.global_cluster_id

  db_subnet_group_name   = module.vpc[each.key].database_subnet_group
  vpc_security_group_ids = [module.vpc[each.key].security_group_ids["database-security-group"]]
  kms_key_id             = data.aws_kms_key.rds_secondary[each.key].arn

  engine                  = var.rds_engine
  engine_version          = var.rds_engine_version
  instance_class          = var.rds_instance_class
  instances               = var.rds_instances
  backup_retention_period = var.rds_backup_retention_period
  deletion_protection     = var.rds_deletion_protection
  skip_final_snapshot     = var.rds_skip_final_snapshot
  enable_write_forwarding = var.rds_enable_write_forwarding

  depends_on = [module.rds_primary]

  providers = {
    aws = aws.regions[each.key]
  }
}

#######################################
##                                   ##
##  Automated Cross-Region Failover  ##
##                                   ##
#######################################

## Deploys a CloudWatch alarm + Lambda + EventBridge wiring that promotes a
## healthy secondary cluster when the primary cluster becomes unreachable.
## Only deployed when at least one DR region exists.
module "rds_failover" {
  source = "./modules/rds-failover-automation"
  count  = var.use_rds && var.rds_failover_enabled && length(var.rds_dr_regions) > 0 ? 1 : 0

  name                     = "${local.standard_customer_name}-aurora-failover"
  global_cluster_id        = module.rds_primary.global_cluster_id
  primary_cluster_id       = module.rds_primary.primary_cluster_id
  allow_data_loss          = var.rds_failover_allow_data_loss
  alarm_evaluation_periods = var.rds_failover_alarm_evaluation_periods
  alarm_period_seconds     = var.rds_failover_alarm_period_seconds
  sns_email_subscribers    = var.rds_failover_sns_subscribers

  depends_on = [module.rds_primary, module.rds_secondary]

  providers = {
    aws = aws.regions[var.primary_region]
  }
}

#########################################################################################
##                                                                                     ##
##                   One-Shot Aurora RDS Preseed (init_remote_db)                      ##
##                                                                                     ##
##  Wraps the ephemeral EC2 that runs the Kasm installer with role `init_remote_db`    ##
##  against a freshly-provisioned Aurora cluster, then self-terminates. Gated by       ##
##  `var.run_remote_db_init`. Re-runs are blocked at two layers:                       ##
##    1. Terraform: lifecycle.ignore_changes = all on the EC2 prevents drift-triggered ##
##       recreation after self-termination.                                            ##
##    2. Userdata: the script queries Aurora for a `kasm_init_marker` sentinel table   ##
##       before invoking the installer, exiting 0 if already present.                  ##
##                                                                                     ##
##  Operators flip var.run_remote_db_init = true once on first deploy and back to      ##
##  false after the SSM status parameter reads `success:<ts>`.                         ##
##                                                                                     ##
##  Resource bodies live in ./modules/remote_db_init. The moved{} blocks below remap   ##
##  pre-module state addresses so this refactor is a no-op for any existing apply.     ##
##                                                                                     ##
#########################################################################################

## Deploys the SSM success-signal placeholder, the IAM policy/role/instance-profile,
## the IAM-propagation sleep, and the ephemeral init EC2 in the primary region.
module "remote_db_init" {
  source = "./modules/remote_db_init"

  ami_id                 = var.remote_db_init_ami_id != "" ? var.remote_db_init_ami_id : data.aws_ami.instance[var.primary_region].id
  aws_account_id         = data.aws_caller_identity.this.account_id
  db_backup_bucket_name  = var.db_backup_bucket_name
  generate_db_preseed    = var.generate_db_preseed
  image_type             = var.image_type
  instance_type          = var.remote_db_init_instance_type
  force_init             = var.force_remote_db_init
  kasm_download_url      = var.kasm_download_url
  kasm_version           = var.kasm_version
  primary_region         = var.primary_region
  private_domain         = local.private_domain
  rds_database_name      = var.rds_database_name
  rds_master_username    = var.rds_master_username
  resource_name_prefix   = local.resource_name_prefix
  run_remote_db_init     = var.run_remote_db_init
  security_group_id      = module.vpc[var.primary_region].security_group_ids["${var.primary_region}-webapp-security-group"]
  sm_admin_cred_arn      = module.aws_sm_user_creds["${local.standard_customer_name}/admin-credential"].secret_arn
  sm_system_cred_arn     = module.aws_sm_system_creds["${local.standard_customer_name}/other-credential"].secret_arn
  sm_user_cred_arn       = module.aws_sm_user_creds["${local.standard_customer_name}/user-credential"].secret_arn
  standard_customer_name = local.standard_customer_name
  subnet_id              = local.webapp_subnet_ids[0]
  use_rds                = var.use_rds
  vpc_cidr               = local.vpc_cidr[var.primary_region]

  providers = {
    aws = aws.regions[var.primary_region]
  }

  depends_on = [
    module.rds_primary,
    module.custom_properties,
    aws_route53_record.database_per_cluster
  ]
}

#######################################
##                                   ##
##   Global Membership Drift Check   ##
##                                   ##
#######################################

## modules/rds-secondary has `lifecycle.ignore_changes = [global_cluster_identifier]`
## (required to support the legitimate failover-promotion path), which means an
## accidental console-driven `PromoteReadReplicaDBCluster` against a secondary
## cluster is INVISIBLE to terraform plan. The cluster silently becomes a
## standalone, replication stops, write-forwarding breaks, and the next thing
## you notice is webapps failing to reach a stale DB.
##
## The check below pulls the live member list from the global cluster (via the
## rds-primary module's `global_cluster_members` output, refreshed each plan)
## and warns if any expected DR region's secondary is missing.
check "rds_secondaries_joined_to_global" {
  assert {
    condition = !var.use_rds || length(var.rds_dr_regions) == 0 || alltrue([
      for region in var.rds_dr_regions :
      anytrue([
        for member in module.rds_primary.global_cluster_members :
        endswith(member.db_cluster_arn, ":cluster:${local.standard_customer_name}-aurora-${region}")
      ])
    ])
    error_message = format(
      "Aurora secondary cluster(s) for region(s) %s are not members of global cluster '%s-aurora-global'. This usually means PromoteReadReplicaDBCluster was called on them (manually via console or by accident); the module's lifecycle.ignore_changes masks this from plan. Recovery: destroy the affected secondary cluster + instance via the AWS API, run `tofu state rm 'module.rds_secondary[\"<region>\"]'`, then re-apply so the cluster is recreated as a proper global secondary. Live members: %s",
      jsonencode([
        for region in var.rds_dr_regions : region
        if !anytrue([
          for member in module.rds_primary.global_cluster_members :
          endswith(member.db_cluster_arn, ":cluster:${local.standard_customer_name}-aurora-${region}")
        ])
      ]),
      local.standard_customer_name,
      jsonencode([for member in module.rds_primary.global_cluster_members : member.db_cluster_arn])
    )
  }
}

#######################################
##                                   ##
##       Database DNS Records        ##
##                                   ##
#######################################

## Per-cluster CNAMEs — one per cluster region. Managers/webapps resolve the
## record matching their resolved manager_db_target (see global_locals.tf).
resource "aws_route53_record" "database_per_cluster" {
  for_each = var.use_rds ? local.cluster_regions : toset([])

  zone_id = aws_route53_zone.private_zone.zone_id
  name    = "database-${each.key}.${local.private_domain}"
  type    = "CNAME"
  ttl     = 60
  records = [
    each.key == var.primary_region
    ? module.rds_primary.primary_cluster_endpoint
    : module.rds_secondary[each.key].cluster_endpoint
  ]

  provider = aws.regions[var.primary_region]
}

## Legacy single-endpoint alias — preserved for backwards compatibility with
## deployments still resolving `database.<private_domain>` directly. Points at
## the primary cluster writer endpoint (RDS) or the VM-based DB private IP
## (legacy). New manager userdata renders the per-region records above.
##
## Caveat: under RDS this record will not auto-update after a cross-region
## failover until a re-apply is run; migrate manager userdata to the per-region
## records before relying on failover automation.
resource "aws_route53_record" "database_legacy" {
  zone_id = aws_route53_zone.private_zone.zone_id
  name    = local.db_private_hostname
  type    = var.use_rds ? "CNAME" : "A"
  ttl     = 60
  records = var.use_rds ? [module.rds_primary.primary_cluster_endpoint] : [module.db_instance.private_ip]

  provider = aws.regions[var.primary_region]
}
