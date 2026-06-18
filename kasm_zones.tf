## ============================================================================
## Kasm zones — one bundled webapp + cpx (+ optional proxy) per zone, where a
## "zone" is either an AWS region in local.all_regions OR an AWS Local Zone in
## local.local_zone_keys. Both shapes flow through a single module call by
## projecting their per-zone wiring into local.kasm_zone_specs.
##
## Provider routing:
##   - aws.webapp points at the resolved webapp placement region for the zone
##     (local.webapp_placement_resolved). For LZ keys this resolves to the
##     parent AWS region, since LZ subnets can't host webapp workloads.
##   - aws.cpx points at the cpx-running region. For regional zones this is
##     the zone itself; for LZ zones this is the LZ's parent AWS region —
##     decoupled from webapp placement so the CPX stays close to the LZ's
##     agents even when webapps are placed in a different region (e.g. to
##     follow an RDS writer).
##   - aws.proxy points at the proxy-running region. For secondary regions
##     this is the zone itself; otherwise deploy_proxy = false and the
##     provider is set to the placement region as a no-op alias.
##   - aws.route53 points at the primary-region provider that owns the
##     private Route53 zone (aws_route53_zone.private_zone in route53.tf).
##
## The nested cpx submodule is gated by var.deploy_cpx and the nested proxy
## submodule by each.value.deploy_proxy, both via the `count = ... ? 1 : 0`
## idiom inside ./modules/kasm_zone/main.tf.
## ============================================================================

locals {
  ## Per-zone spec for the unified kasm_zone module call. Region zones and LZ
  ## zones produce different naming, SG, TG, and userdata wiring; we precompute
  ## both shapes here so the module call below is a clean projection of
  ## each.value.
  ##
  ## Required fields (must match between the two branches so merge() unifies
  ## the object types):
  ##   - cpx_provider_region       : string — AWS region used for aws.cpx and
  ##                                 for any cpx_* lookups. For LZs this is the
  ##                                 placement (parent) region; the values flow
  ##                                 through to the cpx submodule but are
  ##                                 unused because deploy_cpx = false.
  ##   - deploy_proxy              : bool — true only for secondary regions.
  ##   - proxy_provider_region     : string — AWS region used for aws.proxy and
  ##                                 proxy_* lookups. No-op alias when
  ##                                 deploy_proxy = false.
  ##   - proxy_target_group_arns   : map(string) — empty when deploy_proxy is
  ##                                 false; the secondary-region proxy TG
  ##                                 otherwise.
  ##   - proxy_user_data           : string|null — base64-encoded userdata;
  ##                                 null when deploy_proxy is false.
  ##   - private_dns               : object|null — per-zone private DNS A-record
  ##                                 config. null skips record creation.
  ##   - public_dns                : object|null — per-zone public DNS A-record
  ##                                 config. Populated for LZs; null for regional
  ##                                 zones (whose public DNS lives at root).
  ##   - webapp_name_segment       : string — interpolated into webapp launch
  ##                                 template and ASG names. Region key for
  ##                                 regional zones, "lz-${lz}" for LZ zones.
  ##   - webapp_security_group_ids : list(string)
  ##   - webapp_target_group_arns  : map(string)
  ##   - webapp_user_data          : string (base64-encoded)
  kasm_zone_specs = merge(
    {
      for region in local.compute_regions : region => {
        cpx_provider_region   = region
        cpx_user_data         = local.cpx_userdata[region]
        deploy_proxy          = contains(var.secondary_regions, region)
        proxy_provider_region = region
        proxy_target_group_arns = contains(var.secondary_regions, region) ? {
          "${region}-proxy-pub-tg" = local.public_target_group_arns_by_name[region]["${region}-proxy-pub-tg"]
        } : {}
        proxy_user_data = contains(var.secondary_regions, region) ? local.proxy_userdata[region] : null
        private_dns = {
          zone_id     = aws_route53_zone.private_zone.zone_id
          record_name = region
          lb_dns_name = local.webapp_placement_resolved[region] == var.primary_region ? (
            module.private_load_balancer.lb_dns_name
            ) : (
            module.private_load_balancers_regional[local.webapp_placement_resolved[region]].lb_dns_name
          )
          lb_route53_zone = local.webapp_placement_resolved[region] == var.primary_region ? (
            module.private_load_balancer.lb_zone_id
            ) : (
            module.private_load_balancers_regional[local.webapp_placement_resolved[region]].lb_zone_id
          )
        }
        ## Regional public DNS lives at the root (apex + per-region proxy-lb +
        ## optional latency-routed set). It doesn't fit a 1:1-per-zone shape, so
        ## the module's public DNS record is unused for regional zones.
        public_dns = {
          zone_id         = local.route53_public_zone_id
          record_name     = "${region}-proxy-lb"
          lb_dns_name     = module.public_load_balancers[region].lb_dns_name
          lb_route53_zone = module.public_load_balancers[region].lb_zone_id
        }
        webapp_name_segment = region
        webapp_security_group_ids = [
          module.vpc[local.webapp_placement_resolved[region]].security_group_ids["webapp-security-group"],
          module.vpc[var.primary_region].security_group_ids["${region}-webapp-security-group"]
        ]
        ## Private TG for "${region}-webapp-priv-tg" is now created inside
        ## module.kasm_zone (aws_lb_target_group.webapp_private). Only the
        ## external (public-side) TGs flow through here.
        webapp_target_group_arns = {
          "${region}-webapp-pub-tg" = local.public_target_group_arns_by_name[local.webapp_placement_resolved[region]]["${region}-webapp-pub-tg"]
          "webapp-pub-tg"           = local.public_target_group_arns_by_name[local.webapp_placement_resolved[region]]["webapp-pub-tg"]
        }
        webapp_user_data = local.webapp_userdata[region]
      }
    },
    ## LZs whose parent region is in compute_excluded_regions are skipped —
    ## the parent region has no ALB / kasm_zone module to attach to, so an LZ
    ## hanging off it would have nowhere to wire its TGs.
    {
      for lz in local.local_zone_keys : lz => {
        cpx_provider_region     = local.local_zone_parent_region[lz]
        cpx_user_data           = local.local_zones_cpx_userdata[lz]
        deploy_proxy            = false
        proxy_provider_region   = local.local_zone_parent_region[lz]
        proxy_target_group_arns = {}
        proxy_user_data         = null
        private_dns = {
          zone_id     = aws_route53_zone.private_zone.zone_id
          record_name = lz
          lb_dns_name = local.webapp_placement_resolved[lz] == var.primary_region ? (
            module.private_load_balancer.lb_dns_name
            ) : (
            module.private_load_balancers_regional[local.webapp_placement_resolved[lz]].lb_dns_name
          )
          lb_route53_zone = local.webapp_placement_resolved[lz] == var.primary_region ? (
            module.private_load_balancer.lb_zone_id
            ) : (
            module.private_load_balancers_regional[local.webapp_placement_resolved[lz]].lb_zone_id
          )
        }
        public_dns = {
          zone_id         = local.route53_public_zone_id
          record_name     = "${lz}-proxy-lb"
          lb_dns_name     = module.public_load_balancers[local.webapp_placement_resolved[lz]].lb_dns_name
          lb_route53_zone = module.public_load_balancers[local.webapp_placement_resolved[lz]].lb_zone_id
        }
        webapp_name_segment = "lz-${lz}"
        webapp_security_group_ids = [
          module.vpc[local.webapp_placement_resolved[lz]].security_group_ids["webapp-security-group"]
        ]
        webapp_target_group_arns = {
          "${lz}-webapp-pub-tg" = local.public_target_group_arns_by_name[local.webapp_placement_resolved[lz]]["${lz}-webapp-pub-tg"]
          "webapp-pub-tg"       = local.public_target_group_arns_by_name[local.webapp_placement_resolved[lz]]["webapp-pub-tg"]
        }
        webapp_user_data = local.local_zones_webapp_userdata[lz]
      }
      if !contains(var.compute_excluded_regions, local.local_zone_parent_region[lz])
    }
  )
}

module "kasm_zone" {
  source   = "./modules/kasm_zone"
  for_each = local.kasm_zone_specs

  zone_key     = each.key
  deploy_cpx   = var.deploy_cpx
  ssh_key_name = local.ssh_key_name

  ## Placement-region wiring for the owned private TG + listener rule.
  vpc_id                  = module.vpc[local.webapp_placement_resolved[each.key]].vpc_id
  private_lb_listener_arn = local.webapp_placement_resolved[each.key] == var.primary_region ? module.private_load_balancer.https_listener_arn : module.private_load_balancers_regional[local.webapp_placement_resolved[each.key]].https_listener_arn
  private_host_header     = "${each.key}.${local.private_domain}"
  webapp_health_check     = var.webapp_health_check

  webapp_ami_id                = data.aws_ami.instance[local.webapp_placement_resolved[each.key]].id
  webapp_instance_profile_name = module.webapp_role.instance_profile_name
  webapp_instance_type         = var.webapp_instance_type
  webapp_name                  = "${local.resource_name_prefix}-${each.value.webapp_name_segment}-webapp-kasm-instance-template"
  webapp_scale_group_settings = {
    name       = "${local.standard_customer_name}-${each.value.webapp_name_segment}-webapp-asg"
    subnet_ids = local.webapp_subnet_ids_by_region[local.webapp_placement_resolved[each.key]]
  }
  webapp_security_group_ids = each.value.webapp_security_group_ids
  webapp_system_role        = "${each.value.webapp_name_segment}-webapp"
  webapp_target_group_arns  = each.value.webapp_target_group_arns
  webapp_user_data          = each.value.webapp_user_data

  cpx_ami_id                = data.aws_ami.instance[each.value.cpx_provider_region].id
  cpx_instance_profile_name = local.kasminit_instance_profile
  cpx_instance_type         = var.cpx_instance_type
  cpx_name                  = "${local.resource_name_prefix}-${each.value.webapp_name_segment}-cpx-kasm-instance-template"
  cpx_scale_group_settings = {
    name                = "${local.standard_customer_name}-${each.value.webapp_name_segment}-cpx-asg"
    min_size            = 1
    max_size            = 3
    subnet_ids          = local.cpx_subnet_ids[each.value.cpx_provider_region]
    health_check_period = 300
    cool_down_period    = 600
    health_check_type   = "ELB"
    min_health_percent  = 50
  }
  cpx_security_group_ids = [module.vpc[each.value.cpx_provider_region].security_group_ids["cpx-security-group"]]
  cpx_system_role        = "${each.value.cpx_provider_region}-cpx"
  cpx_user_data          = each.value.cpx_user_data

  deploy_proxy                = each.value.deploy_proxy
  proxy_ami_id                = data.aws_ami.instance[each.value.proxy_provider_region].id
  proxy_instance_profile_name = local.kasminit_instance_profile
  proxy_instance_type         = var.proxy_instance_type
  proxy_name                  = "${local.resource_name_prefix}-${each.value.proxy_provider_region}-proxy-kasm-instance-template"
  proxy_scale_group_settings = each.value.deploy_proxy ? {
    name                = "${local.standard_customer_name}-${each.value.proxy_provider_region}-proxy-asg"
    min_size            = 2
    max_size            = 5
    subnet_ids          = local.proxy_subnet_ids[each.value.proxy_provider_region]
    health_check_period = 300
    cool_down_period    = 600
    health_check_type   = "ELB"
    min_health_percent  = 50
  } : null
  proxy_security_group_ids = each.value.deploy_proxy ? [module.vpc[each.value.proxy_provider_region].security_group_ids["proxy-security-group"]] : []
  proxy_system_role        = "${each.value.proxy_provider_region}-proxy"
  proxy_target_group_arns  = each.value.proxy_target_group_arns
  proxy_user_data          = each.value.proxy_user_data

  private_dns = each.value.private_dns
  public_dns  = each.value.public_dns

  providers = {
    aws.webapp  = aws.regions[local.webapp_placement_resolved[each.key]]
    aws.cpx     = aws.regions[each.value.cpx_provider_region]
    aws.proxy   = aws.regions[each.value.proxy_provider_region]
    aws.route53 = aws.regions[var.primary_region]
  }
}

## ============================================================================
## State migration — preserve existing webapp + cpx ASGs as we collapse them
## into module.kasm_zone. moved blocks require literal keys, so we enumerate
## every region declared in local.all_aws_regions (providers.tf). Blocks whose
## source isn't in state are silently ignored; blocks whose target isn't in
## configuration (i.e. the region isn't in local.all_regions for this
## deployment) won't have a matching kasm_zone instance and must be deleted
## or commented out for that deployment.
##
## If any LZ webapps exist in state under module.local_zones_webapp["<lz-az>"],
## add per-LZ blocks of the form:
##
##   moved {
##     from = module.local_zones_webapp["us-east-1-bos-1a"]
##     to   = module.kasm_zone["us-east-1-bos-1a"].module.webapp
##   }
##
## LZ AZ names are deployment-specific (var.local_zones), so we can't enumerate
## them statically here.
## ============================================================================
