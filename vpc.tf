/*
 * AWS Management data queries
 */
## Filter to standard AZs only. Without the opt-in-status filter, once a
## Local Zone is opted in via aws_ec2_availability_zone_group.local_zones,
## it appears in this data source's `names` list and gets picked up by the
## slice() below — breaking RDS subnet groups (LZs are in a different
## network border group) and NAT gateways (most LZs don't support NAT).
## Local Zone subnets are produced separately by local.agent_lz_subnets,
## which iterates var.local_zones directly.
data "aws_availability_zones" "azs" {
  for_each = local.all_regions

  state    = "available"
  provider = aws.regions[each.key]

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

/*
VPC Locals
*/
locals {
  ## Apply var.availability_zone_exclusions before slicing. Match against both
  ## the AZ name (me-central-1b) and the account-specific zone ID (mec1-az2),
  ## so either form excludes the AZ. Needed for regions where AWS lists an AZ
  ## as "available" but rejects CreateSubnet — typically capacity-constrained
  ## AZs in newer regions.
  filtered_availability_zones = {
    for region in local.all_regions : region => [
      for index, az in data.aws_availability_zones.azs[region].names : az
      if !contains(lookup(var.availability_zone_exclusions, region, []), az)
      && !contains(lookup(var.availability_zone_exclusions, region, []), data.aws_availability_zones.azs[region].zone_ids[index])
    ]
  }

  availability_zones = {
    for region in local.all_regions : region => slice(local.filtered_availability_zones[region], 0, min(var.number_of_availability_zones, length(local.filtered_availability_zones[region])))
  }

  vpc_name = var.vpc_name == null ? "${local.standard_customer_name}-vpc" : var.vpc_name

  vpc_cidr = merge(
    {
      (var.primary_region) = var.base_vpc_cidr
    },
    {
      for index, region in var.secondary_regions : region => replace(var.base_vpc_cidr, ".${split(".", var.base_vpc_cidr)[1]}.", ".${index + 1}.")
    }
  )

  vpc_subnet_cidr_mask = {
    for region in local.all_regions : region => split("/", local.vpc_cidr[region])[1]
  }

  subnet_cidr_calculation = {
    for region in local.all_regions : region => (8 - (local.vpc_subnet_cidr_mask[region] - 16))
  }

  subnet_cidr_size = {
    for region in local.all_regions : region => max(4, local.subnet_cidr_calculation[region])
  }

  ## Database subnets are created in every region — they cost nothing when empty,
  ## and pre-creating them means adding a region to var.rds_dr_regions later doesn't
  ## require a subnet-creation step ordered before the Aurora cluster apply. The
  ## VPC module still gates aws_db_subnet_group on var.deploy_rds, so the subnet
  ## group itself only exists where an Aurora cluster lives.
  database_subnets = {
    for region in local.all_regions : region => {
      for index, az in local.availability_zones[region] : "database-subnet-az${index + 1}" => {
        cidr_block               = cidrsubnet(local.vpc_cidr[region], local.subnet_cidr_size[region], index + (length(local.availability_zones[region]) * 0))
        is_public                = false
        availability_zone        = az
        add_dns_record_on_launch = false
        network_acl              = "private_acl"
      }
    }
  }

  ## Webapp subnets are created in every region — they cost nothing when empty
  ## and pre-creating them means adding a zone to var.webapp_deployment_target
  ## later doesn't require a subnet-creation step ordered before the webapp
  ## ASG apply. Same rationale as the database subnets above.
  webapp_subnets = {
    for region in local.all_regions : region => {
      for index, az in local.availability_zones[region] : "webapp-subnet-az${index + 1}" => {
        cidr_block               = cidrsubnet(local.vpc_cidr[region], local.subnet_cidr_size[region], index + (length(local.availability_zones[region]) * 1))
        is_public                = false
        availability_zone        = az
        add_dns_record_on_launch = false
        network_acl              = "private_acl"
      }
    }
  }

  ## Subnets specific to all regions execpet for the mgmt region

  proxy_subnets = {
    for region in var.secondary_regions : region => {
      for index, az in local.availability_zones[region] : "proxy-subnet-az${index + 1}" => {
        cidr_block               = cidrsubnet(local.vpc_cidr[region], local.subnet_cidr_size[region], index + (length(local.availability_zones[region]) * 2))
        is_public                = false
        availability_zone        = az
        add_dns_record_on_launch = false
        network_acl              = "private_acl"
      }
    }
  }

  ## Subnets for all regions

  agent_private_subnets = {
    for region in local.all_regions : region => {
      for index, az in local.availability_zones[region] : "agent-private-subnet-az${index + 1}" => {
        cidr_block               = cidrsubnet(local.vpc_cidr[region], local.subnet_cidr_size[region], index + (length(local.availability_zones[region]) * 3))
        is_public                = false
        availability_zone        = az
        add_dns_record_on_launch = false
        network_acl              = "private_acl"
      }
    }
  }

  agent_public_subnets = {
    for region in local.all_regions : region => {
      for index, az in local.availability_zones[region] : "agent-public-subnet-az${index + 1}" => {
        cidr_block               = cidrsubnet(local.vpc_cidr[region], local.subnet_cidr_size[region], index + (length(local.availability_zones[region]) * 4))
        is_public                = true
        availability_zone        = az
        add_dns_record_on_launch = false
        network_acl              = "public_acl"
      }
    }
  }

  cpx_subnets = {
    for region in local.all_regions : region => {
      for index, az in local.availability_zones[region] : "cpx-subnet-az${index + 1}" => {
        cidr_block               = cidrsubnet(local.vpc_cidr[region], local.subnet_cidr_size[region], index + (length(local.availability_zones[region]) * 5))
        is_public                = false
        availability_zone        = az
        add_dns_record_on_launch = false
        network_acl              = "private_acl"
      }
    }
  }

  public_lb_subnets = {
    for region in local.all_regions : region => {
      for index, az in local.availability_zones[region] : "public-load-balancer-subnet-az${index + 1}" => {
        cidr_block               = cidrsubnet(local.vpc_cidr[region], local.subnet_cidr_size[region], index + (length(local.availability_zones[region]) * 6))
        is_public                = true
        availability_zone        = az
        add_dns_record_on_launch = false
        network_acl              = "public_acl"
      }
    }
  }

  windows_private_subnets = {
    for region in local.all_regions : region => {
      for index, az in local.availability_zones[region] : "windows-private-subnet-az${index + 1}" => {
        cidr_block               = cidrsubnet(local.vpc_cidr[region], local.subnet_cidr_size[region], index + (length(local.availability_zones[region]) * 7))
        is_public                = false
        availability_zone        = az
        add_dns_record_on_launch = false
        network_acl              = "private_acl"
      }
    }
  }

  windows_public_subnets = {
    for region in local.all_regions : region => {
      for index, az in local.availability_zones[region] : "windows-public-subnet-az${index + 1}" => {
        cidr_block               = cidrsubnet(local.vpc_cidr[region], local.subnet_cidr_size[region], index + (length(local.availability_zones[region]) * 8))
        is_public                = true
        availability_zone        = az
        add_dns_record_on_launch = false
        network_acl              = "public_acl"
      }
    }
  }

  ## Flattened {region, lz, index} list used by both the opt-in resource and
  ## the per-LZ subnet/preseed iterations. Only regions actually present in
  ## this deployment (local.all_regions) are considered; LZ keys in
  ## var.local_zones for unknown regions are ignored.
  local_zone_pairs = flatten([
    for region in local.all_regions : [
      for lz, index in lookup(var.local_zones, region, {}) : {
        region = region
        lz     = lz
        index  = index
      }
    ]
  ])

  ## Public agent subnets in Local Zones. Mirrors the agent_public_subnets
  ## pattern (IGW-routed, map_public_ip_on_launch = true), which avoids needing
  ## a NAT gateway in the LZ — most LZs don't support NAT. CIDR offset starts
  ## at 64 to leave headroom past the regular AZ-indexed subnet groups (0..26
  ## with 3 AZs × 9 groups). Index is operator-assigned per LZ in
  ## var.local_zones so adding/removing LZs never shifts existing subnet CIDRs.
  agent_lz_subnets = {
    for region in local.all_regions : region => {
      for lz, index in lookup(var.local_zones, region, {}) :
      "agent-public-subnet-lz-${lz}" => {
        cidr_block               = cidrsubnet(local.vpc_cidr[region], local.subnet_cidr_size[region], 64 + index)
        is_public                = true
        availability_zone        = lz
        add_dns_record_on_launch = false
        network_acl              = "public_acl"
      }
    }
  }

  vpc_subnets = merge(
    {
      (var.primary_region) = merge([
        local.database_subnets[var.primary_region],
        local.webapp_subnets[var.primary_region],
        local.agent_private_subnets[var.primary_region],
        local.agent_public_subnets[var.primary_region],
        local.agent_lz_subnets[var.primary_region],
        local.cpx_subnets[var.primary_region],
        local.public_lb_subnets[var.primary_region],
        local.windows_public_subnets[var.primary_region],
        local.windows_private_subnets[var.primary_region]
      ]...)
    },
    {
      for region in var.secondary_regions : region => merge([
        local.database_subnets[region],
        local.webapp_subnets[region],
        local.proxy_subnets[region],
        local.agent_private_subnets[region],
        local.agent_public_subnets[region],
        local.agent_lz_subnets[region],
        local.cpx_subnets[region],
        local.public_lb_subnets[region],
        local.windows_private_subnets[region],
        local.windows_public_subnets[region]
      ]...)
    }
  )

  mgmt_to_region_routes = {
    for region in var.secondary_regions : region => flatten([[
      {
        route_table_id   = module.vpc[var.primary_region].public_route_table_id
        destination_cidr = local.vpc_cidr[region]
      }],
      [for table in module.vpc[var.primary_region].private_route_table_ids : {
        route_table_id   = table
        destination_cidr = local.vpc_cidr[region]
      }]
    ])
  }

  region_to_mgmt_routes = {
    for region in var.secondary_regions : region => flatten([[
      {
        route_table_id   = module.vpc[region].public_route_table_id
        destination_cidr = local.vpc_cidr[var.primary_region]
      }],
      [for table in module.vpc[region].private_route_table_ids : {
        route_table_id   = table
        destination_cidr = local.vpc_cidr[var.primary_region]
      }]
    ])
  }
}

## Opt into each configured Local Zone in its parent region. The group_name is
## the LZ AZ name with the trailing letter stripped (e.g. "us-east-1-bos-1a"
## → "us-east-1-bos-1"). AWS does not support removing an opt-in via the API,
## so a destroy here is a no-op on the AWS side — acceptable and documented.
resource "aws_ec2_availability_zone_group" "local_zones" {
  for_each = {
    for pair in local.local_zone_pairs : "${pair.region}/${pair.lz}" => pair
  }

  group_name    = replace(each.value.lz, "/[a-z]$/", "")
  opt_in_status = "opted-in"

  provider = aws.regions[each.value.region]
}

/*
 * VPC and subnets
 */
module "vpc" {
  source   = "./modules/vpc"
  for_each = local.all_regions

  azs                = local.availability_zones[each.key]
  deploy_rds         = var.use_rds && (each.key == var.primary_region || contains(var.rds_dr_regions, each.key))
  security_groups    = local.security_groups[each.key]
  subnets            = local.vpc_subnets[each.key]
  single_nat_gateway = var.single_nat_gateway
  vpc_name           = local.vpc_name
  vpc_cidr           = local.vpc_cidr[each.key]

  providers = {
    aws = aws.regions[each.key]
  }

  depends_on = [aws_ec2_availability_zone_group.local_zones]
}

## VPC endpoints to use S3 private service connections
module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 5.0"
  for_each = {
    for region in local.all_regions : region => region
    if var.s3_persistent_profiles || var.s3_storage_provider
  }

  vpc_id                     = module.vpc[each.key].vpc_id
  create_security_group      = true
  security_group_name_prefix = "vpc-endpoints-"
  security_group_description = "VPC endpoint security group"
  security_group_rules = {
    ingress_https = {
      description = "HTTPS from ${each.key} VPC"
      cidr_blocks = [module.vpc[each.key].vpc_cidr_block]
    }
  }

  endpoints = {
    s3 = {
      service = "s3"
      tags = {
        Name = "s3-vpc-endpoint"
      }
    }
  }

  providers = {
    aws = aws.regions[each.key]
  }
}

module "vpc_peering" {
  source   = "./modules/vpc_peering"
  for_each = toset(var.secondary_regions)

  requester_vpc_id = module.vpc[var.primary_region].vpc_id
  requester_routes = local.mgmt_to_region_routes[each.key]
  accepter_region  = each.key
  accepter_vpc_id  = module.vpc[each.key].vpc_id
  accepter_routes  = local.region_to_mgmt_routes[each.key]

  providers = {
    aws.accepter  = aws.regions[each.key]
    aws.requester = aws.regions[var.primary_region]
  }
}