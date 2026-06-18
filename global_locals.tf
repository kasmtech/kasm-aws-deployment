

locals {
  all_regions      = toset(concat([var.primary_region], var.secondary_regions))
  all_regions_list = concat([var.primary_region], var.secondary_regions)
  windows_regions  = setsubtract(local.all_regions, toset(var.windows_excluded_regions))

  ## Regions where compute-tier resources (ALB, WAF, kasm_zone, per-region
  ## ACM cert, per-region public DNS records) deploy. Regions in
  ## var.compute_excluded_regions still get their VPC and security groups so
  ## the networking plumbing is ready when compute is later re-enabled, but
  ## everything that fans out from the public/private ALB is skipped.
  compute_regions           = setsubtract(local.all_regions, toset(var.compute_excluded_regions))
  standard_customer_name    = trim(replace(lower(var.customer_name), "/[ -]/", "-"), "/[$&+,:;=?@#|'<>.^*()%!-]/")
  standard_deployment_type  = trim(replace(lower(var.deployment_type), "/[ -]/", "-"), "/[$&+,:;=?@#|'<>.^*()%!-]/")
  resource_name_prefix      = "${local.standard_customer_name}-${local.standard_deployment_type}"
  mgmt_ssh_key_name         = startswith(var.mgmt_ssh_key, "${local.standard_customer_name}-") ? var.mgmt_ssh_key : "${local.standard_customer_name}-${var.mgmt_ssh_key}"
  ssh_key_name              = startswith(var.ssh_key, "${local.standard_customer_name}-") ? var.ssh_key : "${local.standard_customer_name}-${var.ssh_key}"
  kasminit_role_name        = "${local.resource_name_prefix}-kasm-init-role"
  kasminit_instance_profile = local.kasminit_role_name

  ## Regions that host an Aurora cluster (writer in primary_region, readers in rds_dr_regions).
  ## Used by per-region DB DNS and by manager_db_target_resolved fallback logic.
  cluster_regions = toset(concat([var.primary_region], var.rds_dr_regions))



  #######################################################
  ## Local Zone locals
  ## All locals related to Local Zones should go here:
  ##

  ## Flat list of all Local Zone keys, derived from var.local_zones. Used to
  ## expand the per-zone resolver maps below (webapp placement, manager DB
  ## target, private TG lookup) so LZ "zones" resolve through the same
  ## machinery AWS regions already use.
  local_zone_keys = flatten([
    for region, lzs in var.local_zones : keys(lzs)
    if contains(local.all_regions, region)
  ])

  ## Public-ALB target groups for LZ zones, keyed by placement region. Merged
  ## into local.public_lb_target_groups_new[placement_region] in load-balancers.tf.
  local_zones_public_lb_target_groups_by_placement = {
    for region in local.webapp_placement_regions : region => {
      for lz in local.local_zone_keys : "${lz}-webapp-pub-tg" => {
        port             = 443
        protocol         = "HTTPS"
        protocol_version = "HTTP1"
        target_type      = "instance"
        health_check     = var.webapp_health_check
      }
      if local.webapp_placement_resolved[lz] == region
    }
  }

  ## Public-ALB listener rules — host-based routing on ${lz}.${kasm_domain_name},
  ## keyed by placement region.
  local_zones_public_lb_https_listener_rules_by_placement = {
    for region in local.webapp_placement_regions : region => {
      for lz in local.local_zone_keys : "${lz}-webapp-rule" => {
        target_group = "${lz}-webapp-pub-tg"
        host_headers = ["${lz}.${var.kasm_domain_name}"]
      }
      if local.webapp_placement_resolved[lz] == region
    }
  }

  ## lb_zone_outputs entries for each LZ zone. Merged into local.lb_zone_outputs
  ## in load-balancers.tf so the JSON config consumed by Kasm's autoscale
  ## configuration includes LZ zones. Field semantics mirror the secondary-region
  ## entries at load-balancers.tf:176-194; proxy_hostname targets the LZ's
  ## ${lz}.${kasm_domain_name} subdomain rather than a per-region proxy-lb.
  local_zones_lb_zone_outputs = {
    for lz in local.local_zone_keys : lz => {
      allow_origin_domain          = "$request_host$"
      enable_rdp_https_gw          = true
      enable_rdp_https_gw_dlp      = true
      load_strategy                = "least_load"
      primary_manager_id           = ""
      prioritize_static_agents     = true
      proxy_connections            = true
      proxy_hostname               = "${lz}.${var.kasm_domain_name}"
      proxy_path                   = "desktop"
      proxy_port                   = 443
      proxy_rdp_client_connections = true
      proxy_rdp_hostname           = "${lz}.${var.kasm_domain_name}"
      search_alternate_zones       = true
      upstream_auth_address        = "${lz}.${local.private_domain}"
      verify_rdp_client_ip         = true
      zone_id                      = ""
      zone_name                    = local.local_zone_kasm_names[lz]
    }
  }

  ## Per-LZ Kasm zone name. Operators can add an entry to var.aws_to_kasm_zone_map
  ## keyed by the LZ AZ name to override; absent that, the LZ AZ name itself is
  ## used as the Kasm zone display name.
  local_zone_kasm_names = {
    for lz in local.local_zone_keys : lz => lookup(var.aws_to_kasm_zone_map, lz, lz)
  }

  ## Map of LZ key → parent AWS region. Used wherever an LZ-keyed lookup needs
  ## to fall through to the parent region (placement, DB target, AMI, NFS).
  local_zone_parent_region = merge([
    for region in local.all_regions : {
      for lz in keys(lookup(var.local_zones, region, {})) : lz => region
    }
  ]...)

  ## Resolved manager-to-cluster mapping, one entry per manager region:
  ##   1. Explicit override from var.manager_db_target, if present.
  ##   2. Region-affinity (manager region == cluster region), if the manager's region hosts a cluster.
  ##   3. Fallback to var.primary_region for manager regions without a local cluster.
  ##
  ## Local Zone keys are also included; each LZ resolves to its parent region's
  ## cluster resolution (LZ webapps connect to the same DB as the parent
  ## region's webapps).
  manager_db_target_resolved = {
    for region in toset(concat(tolist(local.all_regions), local.local_zone_keys)) : region =>
    coalesce(
      lookup(var.manager_db_target, region, null),
      contains(local.cluster_regions, region) ? region : (
        contains(local.local_zone_keys, region)
        ? coalesce(
          lookup(var.manager_db_target, local.local_zone_parent_region[region], null),
          contains(local.cluster_regions, local.local_zone_parent_region[region]) ? local.local_zone_parent_region[region] : var.primary_region
        )
        : var.primary_region
      )
    )
  }
  ## Private DNS domain name
  private_domain = "private.${var.kasm_domain_name}"

  ## Full file path for "Managed_By" tag variable
  full_path_list = split("/", abspath(path.module))
  current_folder = element(local.full_path_list, length(local.full_path_list) - 1)

  aws_default_tags = merge(var.freeform_tags, {
    Deployed_by     = "Terraform"
    Managed_by      = local.current_folder
    Project_name    = local.standard_customer_name
    Deployment_type = var.deployment_type
    Customer_name   = local.standard_customer_name
  })

  public_agent_subnet_ids = {
    for region in local.all_regions :
    region => [
      for index, az in local.availability_zones[region] :
      module.vpc[region].subnet_ids["agent-public-subnet-az${index + 1}"]
    ]
  }

  public_windows_subnet_ids = {
    for region in local.all_regions :
    region => [
      for index, az in local.availability_zones[region] :
      module.vpc[region].subnet_ids["windows-public-subnet-az${index + 1}"]
    ]
  }

  private_windows_subnet_ids = {
    for region in local.all_regions :
    region => [
      for index, az in local.availability_zones[region] :
      module.vpc[region].subnet_ids["windows-private-subnet-az${index + 1}"]
    ]
  }

  ## Per-region, per-LZ agent subnet ID lookup. Used by the per-LZ Kasm
  ## autoscale config preseed rows so Kasm launches agents into the specific
  ## Local Zone subnet.
  lz_agent_subnet_ids = {
    for region in local.all_regions :
    region => {
      for lz in keys(lookup(var.local_zones, region, {})) :
      lz => module.vpc[region].subnet_ids["agent-public-subnet-lz-${lz}"]
    }
  }

  cpx_subnet_ids = {
    for region in local.all_regions :
    region => [
      for index, az in local.availability_zones[region] :
      module.vpc[region].subnet_ids["cpx-subnet-az${index + 1}"]
    ]
  }

  proxy_subnet_ids = {
    for region in var.secondary_regions :
    region => [
      for index, az in local.availability_zones[region] :
      module.vpc[region].subnet_ids["proxy-subnet-az${index + 1}"]
    ]
  }

  ## Resolved webapp placement per zone:
  ##   1. Explicit override from var.webapp_deployment_target, if present.
  ##   2. Otherwise default to var.primary_region (today's centralized behavior).
  ##
  ## AWS regions and Local Zone keys are included.
  ## Webapps default to primary regardless of zone type so they sit next to the
  ## DB; CPX / agent placement is handled separately and stays in the zone's
  ## own region. var.webapp_deployment_target can override to land a zone's
  ## webapps in a non-primary AWS region (requires var.use_rds = true).
  webapp_placement_resolved = {
    for zone in toset(concat(tolist(local.all_regions), local.local_zone_keys)) : zone =>
    lookup(var.webapp_deployment_target, zone, var.primary_region)
  }

  ## Set of AWS regions actually receiving webapp deployments. With an empty
  ## webapp_deployment_target this is just { var.primary_region }. With
  ## entries pointing zones at non-primary regions, this expands.
  webapp_placement_regions = toset(values(local.webapp_placement_resolved))

  ## Legacy single-region subnet list. Preserved during the migration window for
  ## any caller that still references it directly. New per-placement consumers
  ## should use local.webapp_subnet_ids_by_region instead.
  webapp_subnet_ids = [
    for index, az in local.availability_zones[var.primary_region] :
    module.vpc[var.primary_region].subnet_ids["webapp-subnet-az${index + 1}"]
  ]

  ## Webapp subnet IDs per region. Webapp subnets are pre-created in every
  ## region's VPC (matching the database-subnet pattern), so this map covers
  ## all of local.all_regions. Consumers index into it by the resolved
  ## placement region — local.webapp_subnet_ids_by_region[local.webapp_placement_resolved[zone]].
  webapp_subnet_ids_by_region = {
    for region in local.all_regions : region => [
      for index, az in local.availability_zones[region] :
      module.vpc[region].subnet_ids["webapp-subnet-az${index + 1}"]
    ]
  }

  database_subnet_ids = [
    for index, az in local.availability_zones[var.primary_region] :
    module.vpc[var.primary_region].subnet_ids["database-subnet-az${index + 1}"]
  ]

  database_subnet_id = length(local.database_subnet_ids) > 0 ? local.database_subnet_ids[0] : null

  management_ssh_public_key = module.ssh_keys[var.mgmt_ssh_key].ssh_key_info.public_key
  agent_ssh_public_key      = module.ssh_keys["agent"].ssh_key_info.public_key
}
