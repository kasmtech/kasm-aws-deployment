locals {
  ## Per-placement-region private LB shape. Each placement region's private LB
  ## carries listener rules and target groups only for the zones whose
  ## webapp_placement_resolved value points at that region. With an empty
  ## var.webapp_deployment_target this collapses to a single primary-region LB
  ## carrying TGs for every zone — identical to the legacy single-LB shape.
  ##
  ## Regional + LZ per-zone private listener rules now live inside
  ## module.kasm_zone (aws_lb_listener_rule.webapp_private).
  private_lb_https_listener_rules_by_placement = {
    for region in local.webapp_placement_regions : region => {}
  }

  private_lb_subnet_ids_by_placement = {
    for region in local.webapp_placement_regions : region => [
      for name, subnet in local.webapp_subnets[region] : module.vpc[region].subnet_ids[name]
    ]
  }

  ## Regional + LZ per-zone private TGs now live inside module.kasm_zone
  ## (aws_lb_target_group.webapp_private).
  private_lb_target_groups_by_placement = {
    for region in local.webapp_placement_regions : region => {}
  }

  public_lb_subnet_names = {
    for region in local.compute_regions : region => keys(local.public_lb_subnets[region])
  }

  public_lb_subnet_ids = {
    for region in local.compute_regions : region => flatten([
      for subnet in local.public_lb_subnet_names[region] : module.vpc[region].subnet_ids[subnet]
    ])
  }

  ## Per-placement-region public listener rules. Each placement region's public
  ## ALB routes its hosted zones' subdomains to the zone-local public webapp TG
  ## on that same ALB. With an empty var.webapp_deployment_target, only the
  ## primary region has rules, and they cover all zones — identical to the
  ## legacy single-region listener config.
  public_lb_https_listener_rules_by_placement = {
    for region in local.webapp_placement_regions : region => merge(
      {
        for zone in local.all_regions_list : "${zone}-webapp-rule" => {
          target_group = "${zone}-webapp-pub-tg"
          host_headers = ["${zone}.${var.kasm_domain_name}"]
        }
        if local.webapp_placement_resolved[zone] == region && !contains(var.compute_excluded_regions, zone)
      },
      local.local_zones_public_lb_https_listener_rules_by_placement[region],
    )
  }

  ## Public ALB target groups, per region. Three shapes:
  ##  1. Primary region: webapp-pub-tg + per-zone TGs for zones placed in primary.
  ##  2. Non-primary placement region: webapp-pub-tg + per-zone TGs for zones placed there + proxy-pub-tg.
  ##  3. Non-placement secondary region: proxy-pub-tg only (today's behavior).
  ##
  ## ALB target groups are regional — an ASG can only attach to TGs in its own region.
  ## When a zone moves placement via var.webapp_deployment_target, its TGs move
  ## with it onto the destination region's public ALB.
  public_lb_target_groups_new = merge(
    {
      (var.primary_region) = merge(
        {
          "webapp-pub-tg" = {
            port             = 443
            protocol         = "HTTPS"
            protocol_version = "HTTP1"
            target_type      = "instance"
            health_check     = var.webapp_health_check
          }
        },
        {
          for zone in local.all_regions_list : "${zone}-webapp-pub-tg" => {
            port             = 443
            protocol         = "HTTPS"
            protocol_version = "HTTP1"
            target_type      = "instance"
            health_check     = var.webapp_health_check
          }
          if local.webapp_placement_resolved[zone] == var.primary_region && !contains(var.compute_excluded_regions, zone)
        },
        local.local_zones_public_lb_target_groups_by_placement[var.primary_region],
      )
    },
    ## Non-primary placement regions: webapp TGs (shared + per-zone) plus their proxy TG.
    {
      for region in setsubtract(setsubtract(local.webapp_placement_regions, [var.primary_region]), toset(var.compute_excluded_regions)) : region => merge(
        {
          "webapp-pub-tg" = {
            port             = 443
            protocol         = "HTTPS"
            protocol_version = "HTTP1"
            target_type      = "instance"
            health_check     = var.webapp_health_check
          }
        },
        {
          for zone in local.all_regions_list : "${zone}-webapp-pub-tg" => {
            port             = 443
            protocol         = "HTTPS"
            protocol_version = "HTTP1"
            target_type      = "instance"
            health_check     = var.webapp_health_check
          }
          if local.webapp_placement_resolved[zone] == region && !contains(var.compute_excluded_regions, zone)
        },
        local.local_zones_public_lb_target_groups_by_placement[region],
        {
          "${region}-proxy-pub-tg" = {
            port             = 443
            protocol         = "HTTPS"
            protocol_version = "HTTP1"
            target_type      = "instance"
            health_check     = var.proxy_health_check
          }
        },
      )
    },
    ## Non-placement secondary regions: proxy TG only (existing behavior).
    {
      for region in setsubtract(setsubtract(toset(var.secondary_regions), local.webapp_placement_regions), toset(var.compute_excluded_regions)) : region => {
        "${region}-proxy-pub-tg" = {
          port             = 443
          protocol         = "HTTPS"
          protocol_version = "HTTP1"
          target_type      = "instance"
          health_check     = var.proxy_health_check
        }
      }
    },
  )

  lb_zone_outputs = merge(
    {
      (var.primary_region) = {
        allow_origin_domain          = "$request_host$"
        enable_rdp_https_gw          = true
        enable_rdp_https_gw_dlp      = true
        load_strategy                = "least_load"
        primary_manager_id           = ""
        prioritize_static_agents     = true
        proxy_connections            = true
        proxy_hostname               = var.kasm_domain_name
        proxy_path                   = "desktop"
        proxy_port                   = 443
        proxy_rdp_client_connections = true
        proxy_rdp_hostname           = var.kasm_domain_name
        search_alternate_zones       = true
        upstream_auth_address        = "${var.primary_region}.${local.private_domain}"
        verify_rdp_client_ip         = true
        zone_id                      = ""
        zone_name                    = var.aws_to_kasm_zone_map[(var.primary_region)]
      }
      }, {
      for region in var.secondary_regions : region => {
        allow_origin_domain          = "$request_host$"
        enable_rdp_https_gw          = true
        enable_rdp_https_gw_dlp      = true
        load_strategy                = "least_load"
        primary_manager_id           = ""
        prioritize_static_agents     = true
        proxy_connections            = true
        proxy_hostname               = "proxy-lb.${var.kasm_domain_name}"
        proxy_path                   = "desktop"
        proxy_port                   = 443
        proxy_rdp_client_connections = true
        proxy_rdp_hostname           = "${region}-proxy-lb.${var.kasm_domain_name}"
        search_alternate_zones       = true
        upstream_auth_address        = "${region}.${local.private_domain}"
        verify_rdp_client_ip         = true
        zone_id                      = ""
        zone_name                    = var.aws_to_kasm_zone_map[region]
      }
      if !contains(var.compute_excluded_regions, region)
    },
    local.local_zones_lb_zone_outputs,
  )
}

module "public_load_balancers" {
  source   = "./modules/alb"
  for_each = local.compute_regions

  access_logs            = {}
  certificate_arn        = module.kasm_domain_cert[each.key].cert_arn
  cors_allow_credentials = "true"
  cors_allow_origin      = "https://${var.kasm_domain_name}"
  ## Default target group: webapp-pub-tg when this region hosts webapps (placement),
  ## proxy-pub-tg otherwise. Listener rules come from the per-placement map when
  ## this region hosts webapps, empty otherwise.
  default_target_group = contains(local.webapp_placement_regions, each.key) ? "webapp-pub-tg" : "${each.key}-proxy-pub-tg"
  https_listener_rules = contains(local.webapp_placement_regions, each.key) ? local.public_lb_https_listener_rules_by_placement[each.key] : {}
  name                 = "${each.key}-public-lb"
  security_groups      = [module.vpc[each.key].security_group_ids["public-lb-security-group"]]
  ssl_policy           = var.public_lb_ssl_policy
  subnets              = local.public_lb_subnet_ids[each.key]
  target_groups_new    = local.public_lb_target_groups_new[each.key]
  vpc_id               = module.vpc[each.key].vpc_id

  providers = {
    aws = aws.regions[each.key]
  }
}

## Public DNS records aliasing each region's public ALB.
##
## Apex handling depends on placement count:
##  - Single placement region (var.webapp_deployment_target = {}): apex is a
##    simple alias to primary's public ALB. Identical to today's behavior.
##  - Multiple placement regions: apex becomes a latency-routed record set
##    (see aws_route53_record.public_lb_apex_latency below). The simple apex
##    is dropped from this resource; per-region proxy-lb records continue.
##
## The transition from simple → latency is intrinsically destructive (Route53
## doesn't allow mixed routing policies for the same name+type), so this is a
## controlled flip when an operator first introduces a non-primary placement.
resource "aws_route53_record" "public_lb_dns_records" {
  for_each = length(local.webapp_placement_regions) > 1 ? toset([
    for region in local.all_regions_list : region
    if region != var.primary_region && !contains(var.compute_excluded_regions, region)
  ]) : local.compute_regions

  allow_overwrite = true
  name            = each.key == var.primary_region ? "" : "${each.key}-proxy-lb"
  type            = "A"
  zone_id         = local.route53_public_zone_id

  alias {
    name                   = module.public_load_balancers[each.key].lb_dns_name
    zone_id                = module.public_load_balancers[each.key].lb_zone_id
    evaluate_target_health = true
  }

  provider = aws.dns
}

## Latency-routed apex record set, one record per placement region. Active only
## when var.webapp_deployment_target produces more than one placement region.
## Each record is a placement-region-targeted alias; Route53 returns whichever
## record has the lowest measured RTT from the resolver's network.
##
## When this resource is inactive (single-placement), the simple apex record
## above continues to serve.
resource "aws_route53_record" "public_lb_apex_latency" {
  for_each = length(local.webapp_placement_regions) > 1 ? setsubtract(local.webapp_placement_regions, toset(var.compute_excluded_regions)) : toset([])

  allow_overwrite = true
  name            = ""
  type            = "A"
  zone_id         = local.route53_public_zone_id
  set_identifier  = each.key

  latency_routing_policy {
    region = each.key
  }

  alias {
    name                   = module.public_load_balancers[each.key].lb_dns_name
    zone_id                = module.public_load_balancers[each.key].lb_zone_id
    evaluate_target_health = true
  }

  provider = aws.dns
}

## Primary region's private LB. Identity unchanged from the pre-refactor shape
## so existing state migrates with no drift. Carries the target groups for any
## zone whose webapp_placement_resolved value points at the primary region —
## which, with an empty var.webapp_deployment_target, is every zone.
module "private_load_balancer" {
  source = "./modules/alb"

  access_logs          = {}
  certificate_arn      = module.kasm_domain_cert[var.primary_region].cert_arn
  https_listener_rules = local.private_lb_https_listener_rules_by_placement[var.primary_region]
  internal             = true
  name                 = "private-lb"
  security_groups      = [module.vpc[var.primary_region].security_group_ids["private-lb-security-group"]]
  ssl_policy           = null
  subnets              = local.private_lb_subnet_ids_by_placement[var.primary_region]
  target_groups_new    = local.private_lb_target_groups_by_placement[var.primary_region]
  vpc_id               = module.vpc[var.primary_region].vpc_id

  providers = {
    aws = aws.regions[var.primary_region]
  }
}

## Per-placement private LBs for any zone whose webapp_placement_resolved is
## NOT the primary region. for_each is empty when var.webapp_deployment_target
## is empty, so existing deployments see no new resources here.
module "private_load_balancers_regional" {
  source   = "./modules/alb"
  for_each = setsubtract(setsubtract(local.webapp_placement_regions, [var.primary_region]), toset(var.compute_excluded_regions))

  access_logs          = {}
  certificate_arn      = module.kasm_domain_cert[each.key].cert_arn
  https_listener_rules = local.private_lb_https_listener_rules_by_placement[each.key]
  internal             = true
  name                 = "${each.key}-private-lb"
  security_groups      = [module.vpc[each.key].security_group_ids["private-lb-security-group"]]
  ssl_policy           = null
  subnets              = local.private_lb_subnet_ids_by_placement[each.key]
  target_groups_new    = local.private_lb_target_groups_by_placement[each.key]
  vpc_id               = module.vpc[each.key].vpc_id

  providers = {
    aws = aws.regions[each.key]
  }
}

## Second-line guard for the regional-webapps + use_rds constraint. Module
## blocks can't carry lifecycle.precondition, so we use a top-level check
## block instead. The var.webapp_deployment_target validation in variables.tf
## is the primary enforcement; this is the belt-and-suspenders check that
## runs at plan time.
check "regional_webapps_requires_rds" {
  assert {
    condition = var.use_rds || alltrue([
      for placement in values(var.webapp_deployment_target) :
      placement == var.primary_region
    ])
    error_message = "Non-primary entries in var.webapp_deployment_target require var.use_rds = true. Either enable RDS + provision an Aurora secondary in the placement region via var.rds_dr_regions, or remove the non-primary entry."
  }
}

## Per-zone private DNS records moved into module.kasm_zone — see
## modules/kasm_zone/main.tf (aws_route53_record.private_lb) and the wiring
## in kasm_zones.tf (each.value.private_dns). LZ keys pass null, suppressing
## record creation, matching pre-refactor behavior.

resource "local_file" "lb_zone_config_json" {
  filename = "${path.module}/${var.lb_zone_config_file}"
  content  = jsonencode(local.lb_zone_outputs)
}
