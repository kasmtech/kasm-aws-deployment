locals {
  security_groups = merge(
    {
      (var.primary_region) = concat(flatten([
        for region in local.all_regions : [
          "${region}-webapp-security-group"
        ]]),
        [
          "agent-security-group",
          "bastion-security-group",
          "cpx-security-group",
          "database-security-group",
          "nfs-security-group",
          "private-lb-security-group",
          "public-lb-security-group",
          ## Per-region webapp SG. The primary VPC's per-zone variants above
          ## (`<zone>-webapp-security-group`) are the legacy in-use SGs; this
          ## non-prefixed `webapp-security-group` is the new convention that
          ## also exists in every secondary VPC, so module.webapp can attach
          ## uniformly regardless of placement.
          "webapp-security-group",
          "windows-security-group"
        ]
      ),
    },
    {
      ## database-security-group is created in every region so that
      ## module.rds_secondary in any rds_dr_region can attach to it. The SG is
      ## empty (default deny) in non-cluster regions and costs nothing.
      ##
      ## webapp-security-group and private-lb-security-group follow the same
      ## pre-create pattern so that adding a zone to var.webapp_deployment_target
      ## later doesn't need a separate SG-creation apply.
      for region in var.secondary_regions : region => [
        "agent-security-group",
        "cpx-security-group",
        "database-security-group",
        "nfs-security-group",
        "private-lb-security-group",
        "proxy-security-group",
        "public-lb-security-group",
        "webapp-security-group",
        "windows-security-group"
      ]
    }
  )

  security_group_rules = merge(
    {
      (var.primary_region) = concat(
        values(local.webapp_sg_rules),
        [
          local.bastion_public_sg_rules,
          local.database_sg_rules,
          local.private_load_balancer_sg_rules,
          local.webapp_sg_rules_by_placement[var.primary_region],
          local.agent_sg_rules[var.primary_region],
          local.cpx_sg_rules[var.primary_region],
          local.nfs_sg_rules[var.primary_region],
          local.public_load_balancer_sg_rules[var.primary_region],
          local.windows_sg_rules[var.primary_region]
      ])
      }, {
      for region in var.secondary_regions : region => concat(
        [
          local.agent_sg_rules[region],
          local.cpx_sg_rules[region],
          local.nfs_sg_rules[region],
          local.private_lb_sg_rules_by_placement[region],
          local.proxy_sg_rules[region],
          local.public_load_balancer_sg_rules[region],
          local.webapp_sg_rules_by_placement[region],
          local.windows_sg_rules[region]
        ],
        contains(var.rds_dr_regions, region) ? [local.database_sg_rules_by_placement[region]] : []
      )
    }
  )

  ## SG Rules for only the mgmt region

  ## Bastion host Public ingress
  bastion_public_sg_rules = {
    sgid                  = module.vpc[var.primary_region].security_group_ids["bastion-security-group"]
    sg_name               = "bastion-security-group"
    enable_default_egress = true
    rules = [
      {
        key         = "ssh-from-public"
        description = "Bastion SSH ingress from Public IPs"
        type        = "ingress"
        protocol    = "tcp"
        from_port   = 22
        to_port     = 22
        cidr_blocks = var.public_ssh_ingress_ips
      }
    ]
  }

  database_sg_rules = {
    sgid                  = module.vpc[var.primary_region].security_group_ids["database-security-group"]
    sg_name               = "database-security-group"
    enable_default_egress = true
    rules = concat(
      [
        for region in local.all_regions : {
          key         = "postgres-from-${region}-webapp"
          description = "Database PostgreSQL ingress from Webapps"
          type        = "ingress"
          protocol    = "tcp"
          from_port   = 5432
          to_port     = 5432
          source_sgid = module.vpc[var.primary_region].security_group_ids["${region}-webapp-security-group"]
        }
        ], [
        {
          key         = "postgres-from-webapp"
          description = "Database PostgreSQL ingress from Webapps"
          type        = "ingress"
          protocol    = "tcp"
          from_port   = 5432
          to_port     = 5432
          source_sgid = module.vpc[var.primary_region].security_group_ids["webapp-security-group"]
        },
        {
          key         = "ssh-from-bastion"
          description = "Database SSH ingress from Bastion Host"
          type        = "ingress"
          protocol    = "tcp"
          from_port   = 22
          to_port     = 22
          source_sgid = module.vpc[var.primary_region].security_group_ids["bastion-security-group"]
        }
      ]
    )
  }

  private_load_balancer_sg_rules = {
    sgid                  = module.vpc[var.primary_region].security_group_ids["private-lb-security-group"]
    sg_name               = "private-lb-security-group"
    enable_default_egress = true
    rules = concat(
      [
        {
          key         = "https-from-agent"
          description = "Private Load Balancer HTTPS ingress from Agent"
          type        = "ingress"
          protocol    = "tcp"
          from_port   = 443
          to_port     = 443
          source_sgid = module.vpc[var.primary_region].security_group_ids["agent-security-group"]
        },
        {
          key         = "https-from-cpx"
          description = "Private Load Balancer HTTPS ingress from CPX"
          type        = "ingress"
          protocol    = "tcp"
          from_port   = 443
          to_port     = 443
          source_sgid = module.vpc[var.primary_region].security_group_ids["cpx-security-group"]
        },
        {
          key         = "https-from-windows"
          description = "Private Load Balancer HTTPS ingress from Windows"
          type        = "ingress"
          protocol    = "tcp"
          from_port   = 443
          to_port     = 443
          source_sgid = module.vpc[var.primary_region].security_group_ids["windows-security-group"]
        }
        ], [
        for region in var.secondary_regions : {
          key         = "https-from-${region}-vpc"
          description = "Private Load Balancer HTTPS ingress from ${region} VPC"
          type        = "ingress"
          protocol    = "tcp"
          from_port   = 443
          to_port     = 443
          cidr_blocks = [local.vpc_cidr[region]]
        }
      ]
    )
  }

  ## Webapp security rules
  webapp_sg_rules = merge(
    {
      (var.primary_region) = {
        sgid                  = module.vpc[var.primary_region].security_group_ids["${var.primary_region}-webapp-security-group"]
        sg_name               = "${var.primary_region}-webapp-security-group"
        enable_default_egress = true
        rules = [
          {
            key         = "https-from-public-lb"
            description = "${var.primary_region} Webapp HTTPS ingress from ${var.primary_region} Public Load Balancer"
            type        = "ingress"
            protocol    = "tcp"
            from_port   = 443
            to_port     = 443
            source_sgid = module.vpc[var.primary_region].security_group_ids["public-lb-security-group"]
          },
          {
            key         = "https-from-private-lb"
            description = "${var.primary_region} Webapp HTTPS ingress from Private Load Balancer"
            type        = "ingress"
            protocol    = "tcp"
            from_port   = 443
            to_port     = 443
            source_sgid = module.vpc[var.primary_region].security_group_ids["private-lb-security-group"]
          },
          {
            key         = "https-from-cpx"
            description = "${var.primary_region} Webapp HTTPS ingress from CPX"
            type        = "ingress"
            protocol    = "tcp"
            from_port   = 443
            to_port     = 443
            source_sgid = module.vpc[var.primary_region].security_group_ids["cpx-security-group"]
          },
          {
            key         = "https-from-agent"
            description = "${var.primary_region} Webapp HTTPS ingress from Agent"
            type        = "ingress"
            protocol    = "tcp"
            from_port   = 443
            to_port     = 443
            source_sgid = module.vpc[var.primary_region].security_group_ids["agent-security-group"]
          },
          {
            key         = "https-from-windows"
            description = "${var.primary_region} Webapp HTTPS ingress from Windows Agent"
            type        = "ingress"
            protocol    = "tcp"
            from_port   = 443
            to_port     = 443
            source_sgid = module.vpc[var.primary_region].security_group_ids["windows-security-group"]
          }
        ]
      }
    },
    {
      for region in var.secondary_regions : region => {
        sgid                  = module.vpc[var.primary_region].security_group_ids["${region}-webapp-security-group"]
        sg_name               = "${region}-webapp-security-group"
        enable_default_egress = true
        rules = [
          {
            key         = "https-from-public-lb"
            description = "${region} Webapp HTTPS ingress from ${var.primary_region} Public Load Balancer"
            type        = "ingress"
            protocol    = "tcp"
            from_port   = 443
            to_port     = 443
            source_sgid = module.vpc[var.primary_region].security_group_ids["public-lb-security-group"]
          },
          {
            key         = "https-from-private-lb"
            description = "${region} Webapp HTTPS ingress from ${region} Private Load Balancer"
            type        = "ingress"
            protocol    = "tcp"
            from_port   = 443
            to_port     = 443
            source_sgid = module.vpc[var.primary_region].security_group_ids["private-lb-security-group"]
          },
          {
            key         = "https-from-private-agent"
            description = "${region} Webapp HTTPS ingress from Private Agent"
            type        = "ingress"
            protocol    = "tcp"
            from_port   = 443
            to_port     = 443
            cidr_blocks = values(local.agent_private_subnets[region])[*].cidr_block
          },
          {
            key         = "https-from-public-agent"
            description = "${region} Webapp HTTPS ingress from Public Agent"
            type        = "ingress"
            protocol    = "tcp"
            from_port   = 443
            to_port     = 443
            cidr_blocks = concat(
              values(local.agent_public_subnets[region])[*].cidr_block,
              values(local.agent_lz_subnets[region])[*].cidr_block
            )
          },
          {
            key         = "https-from-cpx"
            description = "${region} Webapp HTTPS ingress from CPX"
            type        = "ingress"
            protocol    = "tcp"
            from_port   = 443
            to_port     = 443
            cidr_blocks = values(local.cpx_subnets[region])[*].cidr_block
          },
          {
            key         = "https-from-private-windows"
            description = "${region} Webapp HTTPS ingress from Private Windows"
            type        = "ingress"
            protocol    = "tcp"
            from_port   = 443
            to_port     = 443
            cidr_blocks = values(local.windows_private_subnets[region])[*].cidr_block
          },
          {
            key         = "https-from-public-windows"
            description = "${region} Webapp HTTPS ingress from Public Windows"
            type        = "ingress"
            protocol    = "tcp"
            from_port   = 443
            to_port     = 443
            cidr_blocks = values(local.windows_public_subnets[region])[*].cidr_block
          }
        ]
      }
    }
  )

  ## Per-region webapp SG rules. The new `webapp-security-group` (non-prefixed)
  ## exists in every region's VPC and is the attach point for webapp ASGs whose
  ## placement maps them to that region via var.webapp_deployment_target. With
  ## an empty placement map this SG has no instances attached anywhere; the
  ## rules below are still installed (cost nothing) so the SG is ready when
  ## operators flip a zone's placement.
  ##
  ## Ingress: HTTPS from the load balancers + agent/cpx/windows in the same
  ## region. Egress: default 0.0.0.0/0.
  webapp_sg_rules_by_placement = {
    for region in local.all_regions : region => {
      sgid                  = module.vpc[region].security_group_ids["webapp-security-group"]
      sg_name               = "webapp-security-group"
      enable_default_egress = true
      rules = [
        {
          key         = "https-from-public-lb"
          description = "Webapp HTTPS ingress from Public LB"
          type        = "ingress"
          protocol    = "tcp"
          from_port   = 443
          to_port     = 443
          source_sgid = module.vpc[region].security_group_ids["public-lb-security-group"]
        },
        {
          key         = "https-from-private-lb"
          description = "Webapp HTTPS ingress from Private LB"
          type        = "ingress"
          protocol    = "tcp"
          from_port   = 443
          to_port     = 443
          source_sgid = module.vpc[region].security_group_ids["private-lb-security-group"]
        },
        {
          key         = "https-from-agent"
          description = "Webapp HTTPS ingress from Agent"
          type        = "ingress"
          protocol    = "tcp"
          from_port   = 443
          to_port     = 443
          source_sgid = module.vpc[region].security_group_ids["agent-security-group"]
        },
        {
          key         = "https-from-cpx"
          description = "Webapp HTTPS ingress from CPX"
          type        = "ingress"
          protocol    = "tcp"
          from_port   = 443
          to_port     = 443
          source_sgid = module.vpc[region].security_group_ids["cpx-security-group"]
        },
        {
          key         = "https-from-windows"
          description = "Webapp HTTPS ingress from Windows"
          type        = "ingress"
          protocol    = "tcp"
          from_port   = 443
          to_port     = 443
          source_sgid = module.vpc[region].security_group_ids["windows-security-group"]
        }
      ]
    }
  }

  ## Per-region database SG rules for non-primary cluster regions. The primary
  ## DB SG rules are defined above (`database_sg_rules`); this block adds
  ## equivalent ingress rules to the database SG in each non-primary cluster
  ## region (regions in var.rds_dr_regions). Without this, Aurora secondary
  ## clusters in DR regions have no ingress and webapps placed there can't
  ## connect to them.
  ##
  ## Source SG is the region-local `webapp-security-group` (per-placement
  ## webapps attach to this); not the legacy primary-VPC per-zone SGs which
  ## live in a different VPC and wouldn't be referenceable across regions.
  database_sg_rules_by_placement = {
    for region in setsubtract(toset(var.rds_dr_regions), [var.primary_region]) : region => {
      sgid                  = module.vpc[region].security_group_ids["database-security-group"]
      sg_name               = "database-security-group"
      enable_default_egress = true
      rules = [
        {
          key         = "postgres-from-webapp"
          description = "Database PostgreSQL ingress from Webapps in ${region}"
          type        = "ingress"
          protocol    = "tcp"
          from_port   = 5432
          to_port     = 5432
          source_sgid = module.vpc[region].security_group_ids["webapp-security-group"]
        },
        {
          key         = "ssh-from-bastion-drg"
          description = "Database SSH ingress from Bastion (cross-region via DRG)"
          type        = "ingress"
          protocol    = "tcp"
          from_port   = 22
          to_port     = 22
          cidr_blocks = values(local.public_lb_subnets[var.primary_region])[*].cidr_block
        }
      ]
    }
  }

  ## Per-region private LB SG rules. The primary region's private LB rules are
  ## defined separately above (`private_load_balancer_sg_rules`) for backwards
  ## compat; this block defines equivalent rules for the secondary regions
  ## that may host a private LB when their zone is in webapp_deployment_target.
  ## Ingress allows webapp + agent + cpx + windows reach via 443.
  private_lb_sg_rules_by_placement = {
    for region in var.secondary_regions : region => {
      sgid                  = module.vpc[region].security_group_ids["private-lb-security-group"]
      sg_name               = "private-lb-security-group"
      enable_default_egress = true
      rules = [
        {
          key         = "https-from-webapp"
          description = "Private LB HTTPS ingress from Webapp"
          type        = "ingress"
          protocol    = "tcp"
          from_port   = 443
          to_port     = 443
          source_sgid = module.vpc[region].security_group_ids["webapp-security-group"]
        },
        {
          key         = "https-from-agent"
          description = "Private LB HTTPS ingress from Agent"
          type        = "ingress"
          protocol    = "tcp"
          from_port   = 443
          to_port     = 443
          source_sgid = module.vpc[region].security_group_ids["agent-security-group"]
        },
        {
          key         = "https-from-cpx"
          description = "Private LB HTTPS ingress from CPX"
          type        = "ingress"
          protocol    = "tcp"
          from_port   = 443
          to_port     = 443
          source_sgid = module.vpc[region].security_group_ids["cpx-security-group"]
        },
        {
          key         = "https-from-windows"
          description = "Private LB HTTPS ingress from Windows"
          type        = "ingress"
          protocol    = "tcp"
          from_port   = 443
          to_port     = 443
          source_sgid = module.vpc[region].security_group_ids["windows-security-group"]
        }
      ]
    }
  }

  ## SG Rules that get applied to all regions

  ## Agent security rules
  agent_sg_rules = {
    for region in local.all_regions : region => {
      sgid                  = module.vpc[region].security_group_ids["agent-security-group"]
      sg_name               = "agent-security-group"
      enable_default_egress = true
      rules = concat(
        region == var.primary_region ? [
          {
            key         = "https-from-webapp"
            description = "Agent HTTPS ingress from Webapp"
            type        = "ingress"
            protocol    = "tcp"
            from_port   = 443
            to_port     = 443
            cidr_blocks = [""]
            source_sgid = module.vpc[var.primary_region].security_group_ids["webapp-security-group"]
          },
          {
            key         = "ssh-from-bastion"
            description = "Agent SSH ingress from Bastion Host"
            type        = "ingress"
            protocol    = "tcp"
            from_port   = 22
            to_port     = 22
            cidr_blocks = [""]
            source_sgid = module.vpc[var.primary_region].security_group_ids["bastion-security-group"]
          }
          ] : [
          {
            key         = "ssh-from-bastion-drg"
            description = "Agent SSH ingress Bastion"
            type        = "ingress"
            protocol    = "tcp"
            from_port   = 22
            to_port     = 22
            cidr_blocks = values(local.public_lb_subnets[var.primary_region])[*].cidr_block #### Replace me with actual solution ####
            source_sgid = ""
          },
          {
            key         = "https-from-webapp-cidr"
            description = "Agent HTTPS ingress ${region} Webapp"
            type        = "ingress"
            protocol    = "tcp"
            from_port   = 443
            to_port     = 443
            cidr_blocks = values(local.webapp_subnets[var.primary_region])[*].cidr_block
            source_sgid = ""
          }
        ]
      )
    }
  }

  cpx_sg_rules = {
    for region in local.all_regions : region => {
      sgid                  = module.vpc[region].security_group_ids["cpx-security-group"]
      sg_name               = "cpx-security-group"
      enable_default_egress = true
      rules = concat(
        region == var.primary_region ? [
          {
            key         = "https-from-region-webapp"
            description = "CPX HTTPS ingress from Webapp"
            type        = "ingress"
            protocol    = "tcp"
            from_port   = 443
            to_port     = 443
            cidr_blocks = [""]
            source_sgid = module.vpc[region].security_group_ids["${region}-webapp-security-group"]
          },
          {
            key         = "https-from-webapp"
            description = "CPX HTTPS ingress from Webapp"
            type        = "ingress"
            protocol    = "tcp"
            from_port   = 443
            to_port     = 443
            cidr_blocks = [""]
            source_sgid = module.vpc[region].security_group_ids["webapp-security-group"]
          }
          ] : [
          {
            key         = "https-from-webapp-cidr"
            description = "CPX HTTPS ingress ${region} Webapp"
            type        = "ingress"
            protocol    = "tcp"
            from_port   = 443
            to_port     = 443
            cidr_blocks = values(local.webapp_subnets[var.primary_region])[*].cidr_block
            source_sgid = ""
          },
          {
            key         = "https-from-proxy"
            description = "CPX HTTPS ingress from ${region} Proxy"
            type        = "ingress"
            protocol    = "tcp"
            from_port   = 443
            to_port     = 443
            cidr_blocks = [""]
            source_sgid = module.vpc[region].security_group_ids["proxy-security-group"]
          }
        ]
      )
    }
  }

  nfs_sg_rules = {
    for region in local.all_regions : region => {
      sgid                  = module.vpc[region].security_group_ids["nfs-security-group"]
      sg_name               = "nfs-security-group"
      enable_default_egress = true
      rules = [
        {
          key         = "nfs-from-agent"
          description = "NFS share access from Agents"
          type        = "ingress"
          protocol    = "tcp"
          from_port   = 2049
          to_port     = 2049
          source_sgid = module.vpc[region].security_group_ids["agent-security-group"]
        }
      ]
    }
  }

  proxy_sg_rules = {
    for region in var.secondary_regions : region => {
      sgid                  = module.vpc[region].security_group_ids["proxy-security-group"]
      sg_name               = "proxy-security-group"
      enable_default_egress = true
      rules = [
        {
          key         = "ssh-from-bastion-drg"
          description = "Proxy SSH ingress Bastion"
          type        = "ingress"
          protocol    = "tcp"
          from_port   = 22
          to_port     = 22
          cidr_blocks = values(local.public_lb_subnets[var.primary_region])[*].cidr_block #### Replace me with actual solution ####
          source_sgid = ""
        },
        {
          key         = "https-from-public-lb"
          description = "Proxy HTTPS ingress from Proxy Host"
          type        = "ingress"
          protocol    = "tcp"
          from_port   = 443
          to_port     = 443
          cidr_blocks = [""]
          source_sgid = module.vpc[region].security_group_ids["public-lb-security-group"]
        }
      ]
    }
  }

  ## Public Load Balancer Public ingress
  public_load_balancer_sg_rules = {
    for region in local.all_regions : region => {
      sgid                  = module.vpc[region].security_group_ids["public-lb-security-group"]
      sg_name               = "public-lb-security-group"
      enable_default_egress = true
      rules = [
        {
          key         = "https-from-public"
          description = "Public Load balancer HTTPS ingress"
          type        = "ingress"
          protocol    = "tcp"
          from_port   = 443
          to_port     = 443
          cidr_blocks = var.public_web_access_ips
        },
        {
          key         = "http-from-public"
          description = "Public Load balancer HTTP ingress"
          type        = "ingress"
          protocol    = "tcp"
          from_port   = 80
          to_port     = 80
          cidr_blocks = var.public_web_access_ips
        }
      ]
    }
  }

  ## Windows security rules
  windows_sg_rules = {
    for region in local.all_regions : region => {
      sgid                  = module.vpc[region].security_group_ids["windows-security-group"]
      sg_name               = "windows-security-group"
      enable_default_egress = true
      rules = concat(
        region == var.primary_region ? [
          {
            key         = "rdp-from-cpx"
            description = "Windows RDP ingress from CPX"
            type        = "ingress"
            protocol    = "tcp"
            from_port   = 3389
            to_port     = 3389
            cidr_blocks = tolist([""])
            source_sgid = module.vpc[var.primary_region].security_group_ids["cpx-security-group"]
          },
          {
            key         = "kasm-vnc-from-cpx"
            description = "Windows RDP ingress from CPX"
            type        = "ingress"
            protocol    = "tcp"
            from_port   = 4902
            to_port     = 4902
            cidr_blocks = tolist([""])
            source_sgid = module.vpc[var.primary_region].security_group_ids["cpx-security-group"]
          },
          {
            key         = "kasm-vnc-from-webapp"
            description = "Windows KasmVNC ingress Webapp"
            type        = "ingress"
            protocol    = "tcp"
            from_port   = 4902
            to_port     = 4902
            cidr_blocks = tolist([""])
            source_sgid = module.vpc[var.primary_region].security_group_ids["webapp-security-group"]
          }
          ] : [
          {
            key         = "rdp-from-cpx"
            description = "Windows RDP ingress from CPX"
            type        = "ingress"
            protocol    = "tcp"
            from_port   = 3389
            to_port     = 3389
            cidr_blocks = tolist([""])
            source_sgid = module.vpc[region].security_group_ids["cpx-security-group"]
          },
          {
            key         = "kasm-vnc-from-cpx"
            description = "Windows Kasm Agent ingress from CPX"
            type        = "ingress"
            protocol    = "tcp"
            from_port   = 4902
            to_port     = 4902
            cidr_blocks = tolist([""])
            source_sgid = module.vpc[region].security_group_ids["cpx-security-group"]
          },
          {
            key         = "kasm-vnc-from-primary-vpc-nat-gw"
            description = "Windows Kasm Agent ingress from primary region VPC NAT GW"
            type        = "ingress"
            protocol    = "tcp"
            from_port   = 4902
            to_port     = 4902
            cidr_blocks = tolist([for ip in module.vpc[var.primary_region].nat_public_ips : "${ip}/32"])
            source_sgid = ""
          },
          {
            key         = "kasm-vnc-from-webapp-cidr"
            description = "Windows Kasm Agent ingress from ${region} Webapp"
            type        = "ingress"
            protocol    = "tcp"
            from_port   = 4902
            to_port     = 4902
            cidr_blocks = tolist(values(local.webapp_subnets[var.primary_region])[*].cidr_block)
            source_sgid = ""
          }
        ],
        [
          {
            key         = "kasm-vnc-from-nat"
            description = "Windows VNC ingress from Nat Gateway IP(s)"
            type        = "ingress"
            protocol    = "tcp"
            from_port   = 4902
            to_port     = 4902
            cidr_blocks = tolist([for ip in module.vpc[region].nat_public_ips : "${ip}/32"])
            source_sgid = ""
          },
          {
            key         = "rdp-from-nat"
            description = "Windows RDP ingress from Nat Gateway IP(s)"
            type        = "ingress"
            protocol    = "tcp"
            from_port   = 3389
            to_port     = 3389
            cidr_blocks = tolist([for ip in module.vpc[region].nat_public_ips : "${ip}/32"])
            source_sgid = ""
          }
        ]
      )
    }
  }
}

module "sg_rules" {
  source   = "./modules/security_group_rules"
  for_each = local.all_regions

  sg_rules = local.security_group_rules[each.key]

  providers = {
    aws = aws.regions[each.key]
  }
}
