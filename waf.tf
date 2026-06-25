locals {
  waf_name = {
    for region in local.compute_regions : region => "${local.standard_customer_name}-${region}-waf"
  }
}

module "waf" {
  source = "./modules/waf"
  for_each = {
    for region in local.compute_regions : region => region
    if var.deploy_waf
  }

  name        = local.waf_name[each.key]
  description = "${each.key} WAF"
  load_balancer_arns = {
    "${each.key}-public-lb" = module.public_load_balancers[each.key].lb_arn
  }
  admin_bypass_ips  = var.waf_bypass_ips
  waf_s3_bucket_arn = ""

  providers = {
    aws = aws.regions[each.key]
  }
}
