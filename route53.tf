locals {
  delegate_ns_to_parent = var.create_route53_zone && var.parent_dns_zone_name != ""

  kasm_public_dns_zone_data = {
    (var.kasm_domain_name) = {
      comment = "${title(local.standard_customer_name)} - ${title(var.deployment_type)} - ${var.kasm_domain_name}"
      tags = {
        Name = var.kasm_domain_name
      }
    }
  }

  route53_public_zone_id = var.create_route53_zone ? aws_route53_zone.public_zone[0].zone_id : data.aws_route53_zone.public_zone[0].zone_id
}

resource "aws_route53_zone" "public_zone" {
  count = var.create_route53_zone ? 1 : 0

  name = var.kasm_domain_name

  provider = aws.dns
}

data "aws_route53_zone" "public_zone" {
  count = var.create_route53_zone ? 0 : 1

  name         = var.kasm_domain_name
  private_zone = false

  provider = aws.dns
}


## Look up the parent DNS zone in the DNS account so we can delegate the customer subdomain to it.
data "aws_route53_zone" "parent" {
  count = local.delegate_ns_to_parent ? 1 : 0

  name         = var.parent_dns_zone_name
  private_zone = false

  provider = aws.dns
}

## NS delegation record in the parent zone, pointing the customer subdomain at the new public zone's name servers.
resource "aws_route53_record" "ns_delegation" {
  count = local.delegate_ns_to_parent ? 1 : 0

  zone_id = data.aws_route53_zone.parent[0].zone_id
  name    = split(".", var.kasm_domain_name)[0]
  type    = "NS"
  ttl     = 300
  records = aws_route53_zone.public_zone[0].name_servers

  provider = aws.dns
}

resource "aws_route53_zone" "private_zone" {
  name = local.private_domain

  dynamic "vpc" {
    for_each = local.all_regions

    content {
      vpc_id     = module.vpc[vpc.key].vpc_id
      vpc_region = vpc.key
    }
  }

  provider = aws.regions[var.primary_region]
}

module "kasm_domain_cert" {
  source   = "./modules/acm_certificate"
  for_each = local.compute_regions

  domain_name               = var.kasm_domain_name
  subject_alternative_names = ["*.${var.kasm_domain_name}"]
  zone_id                   = local.route53_public_zone_id

  providers = {
    aws.cert = aws.regions[each.key]
    aws.dns  = aws.dns
  }
}
