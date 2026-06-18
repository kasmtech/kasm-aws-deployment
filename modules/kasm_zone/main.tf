## Per-zone private webapp target group on the placement-region private ALB.
## The TG resource itself is region-scoped (anchored via vpc_id); the listener
## rule below attaches it to the placement-region private LB's listener.
resource "aws_lb_target_group" "webapp_private" {
  ## AWS caps target group names at 32 characters and rejects names ending in
  ## a hyphen. LZ-prefixed zone keys like "eu-central-1-waw-1a" push the full
  ## "<zone>-webapp-priv-tg" past 32; truncate, then strip any trailing hyphen
  ## that the cut may have left behind. The full unsuffixed name lives on the
  ## Name tag below.
  name             = trimsuffix(substr("${var.zone_key}-webapp-priv-tg", 0, 32), "-")
  port             = 443
  protocol         = "HTTPS"
  protocol_version = "HTTP1"
  target_type      = "instance"
  vpc_id           = var.vpc_id

  health_check {
    enabled             = var.webapp_health_check.enabled
    interval            = var.webapp_health_check.interval_in_sec
    path                = var.webapp_health_check.path
    port                = var.webapp_health_check.port
    healthy_threshold   = var.webapp_health_check.healthy_threshold
    unhealthy_threshold = var.webapp_health_check.unhealthy_threshold
    timeout             = var.webapp_health_check.timeout_in_sec
    protocol            = var.webapp_health_check.protocol
    matcher             = var.webapp_health_check.matcher
  }

  tags = {
    Name = "${var.zone_key}-webapp-priv-tg"
  }

  lifecycle {
    create_before_destroy = true
  }

  provider = aws.webapp
}

## Per-zone private listener rule — host-routes "${var.private_host_header}"
## to the owned private TG above.
resource "aws_lb_listener_rule" "webapp_private" {
  listener_arn = var.private_lb_listener_arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webapp_private.arn
  }

  condition {
    host_header {
      values = [var.private_host_header]
    }
  }

  provider = aws.webapp
}

## Deploy the zone's Webapp ASG via the shared autoscale module.
##
## target_group_arns merges:
##   - the owned private TG above (keyed "${zone_key}-webapp-priv-tg" to match
##     pre-refactor state)
##   - var.webapp_target_group_arns from the caller (the public TGs that still
##     live in modules/alb today)
module "webapp" {
  source = "../autoscale"

  ami_id                = var.webapp_ami_id
  instance_profile_name = var.webapp_instance_profile_name
  instance_type         = var.webapp_instance_type
  name                  = var.webapp_name
  scale_group_settings  = var.webapp_scale_group_settings
  security_group_ids    = var.webapp_security_group_ids
  ssh_key_name          = var.ssh_key_name
  system_role           = var.webapp_system_role
  target_group_arns = merge(
    var.webapp_target_group_arns,
    {
      "${var.zone_key}-webapp-priv-tg" = aws_lb_target_group.webapp_private.arn
    },
  )
  user_data = var.webapp_user_data

  providers = {
    aws = aws.webapp
  }
}

## Deploy the zone's Connection Proxy ASG via the shared autoscale module.
module "cpx" {
  source = "../autoscale"
  count  = var.deploy_cpx ? 1 : 0

  ami_id                = var.cpx_ami_id
  instance_profile_name = var.cpx_instance_profile_name
  instance_type         = var.cpx_instance_type
  name                  = var.cpx_name
  scale_group_settings  = var.cpx_scale_group_settings
  security_group_ids    = var.cpx_security_group_ids
  ssh_key_name          = var.ssh_key_name
  system_role           = var.cpx_system_role
  user_data             = var.cpx_user_data

  providers = {
    aws = aws.cpx
  }
}

## Deploy the zone's Proxy ASG (secondary regions only).
module "proxy" {
  source = "../autoscale"
  count  = var.deploy_proxy ? 1 : 0

  ami_id                = var.proxy_ami_id
  instance_profile_name = var.proxy_instance_profile_name
  instance_type         = var.proxy_instance_type
  name                  = var.proxy_name
  scale_group_settings  = var.proxy_scale_group_settings
  security_group_ids    = var.proxy_security_group_ids
  ssh_key_name          = var.ssh_key_name
  system_role           = var.proxy_system_role
  target_group_arns     = var.proxy_target_group_arns
  user_data             = var.proxy_user_data

  providers = {
    aws = aws.proxy
  }
}

## Per-zone private DNS A-record. Aliases the placement-region's private LB.
## Omitted (count = 0) when var.private_dns is null.
resource "aws_route53_record" "private_lb" {
  count = var.private_dns == null ? 0 : 1

  allow_overwrite = true
  zone_id         = var.private_dns.zone_id
  name            = var.private_dns.record_name
  type            = "A"

  alias {
    name                   = var.private_dns.lb_dns_name
    zone_id                = var.private_dns.lb_route53_zone
    evaluate_target_health = true
  }

  provider = aws.route53
}

## Per-zone public DNS A-record. Aliases the placement-region's public ALB.
## Omitted (count = 0) when var.public_dns is null — regional zones leave this
## null because their public DNS is handled at the root (apex / latency).
resource "aws_route53_record" "public_lb" {
  count = var.public_dns == null ? 0 : 1

  allow_overwrite = true
  zone_id         = var.public_dns.zone_id
  name            = var.public_dns.record_name
  type            = "A"

  alias {
    name                   = var.public_dns.lb_dns_name
    zone_id                = var.public_dns.lb_route53_zone
    evaluate_target_health = true
  }

  provider = aws.route53
}
