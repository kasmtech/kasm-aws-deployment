resource "aws_lb" "this" {
  name               = var.name
  load_balancer_type = "application"
  internal           = var.internal
  security_groups    = var.security_groups
  subnets            = var.subnets

  dynamic "access_logs" {
    for_each = length(var.access_logs) > 0 ? [var.access_logs] : []

    content {
      enabled = try(access_logs.value.enabled, try(access_logs.value.bucket, null) != null)
      bucket  = try(access_logs.value.bucket, null)
      prefix  = try(access_logs.value.prefix, null)
    }
  }

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )

  timeouts {
    create = "60m"
  }
}

resource "aws_lb_target_group" "this" {
  for_each = var.target_groups_new

  port             = each.value.port
  protocol         = each.value.protocol
  protocol_version = each.value.protocol_version
  ## AWS caps target group names at 32 characters and rejects names ending in
  ## a hyphen. LZ-prefixed keys like "eu-central-1-waw-1a-webapp-pub-tg"
  ## exceed 32; truncate, then strip any trailing hyphen that the cut may have
  ## left behind. The full key remains the resource map key and the Name tag
  ## below, so lookups and display naming are unaffected.
  name        = trimsuffix(substr(each.key, 0, 32), "-")
  target_type = each.value.target_type
  vpc_id      = var.vpc_id

  health_check {
    enabled             = each.value.health_check.enabled
    interval            = each.value.health_check.interval_in_sec
    path                = each.value.health_check.path
    port                = each.value.health_check.port
    healthy_threshold   = each.value.health_check.healthy_threshold
    unhealthy_threshold = each.value.health_check.unhealthy_threshold
    timeout             = each.value.health_check.timeout_in_sec
    protocol            = each.value.health_check.protocol
    matcher             = each.value.health_check.matcher
  }


  tags = merge(
    var.tags,
    {
      Name = each.key
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "http" {

  load_balancer_arn = aws_lb.this.arn

  port     = 80
  protocol = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {

  certificate_arn   = var.certificate_arn
  load_balancer_arn = aws_lb.this.arn

  port     = 443
  protocol = "HTTPS"

  ssl_policy = var.ssl_policy

  routing_http_response_access_control_allow_credentials_header_value = var.cors_allow_credentials
  routing_http_response_access_control_allow_origin_header_value      = var.cors_allow_origin

  default_action {
    type             = var.default_target_group == "" ? "fixed-response" : "forward"
    target_group_arn = var.default_target_group == "" ? null : aws_lb_target_group.this[var.default_target_group].arn

    dynamic "fixed_response" {
      for_each = var.default_target_group == "" ? [1] : []
      content {
        content_type = "text/plain"
        message_body = "Fixed response content"
        status_code  = 200
      }
    }
  }
}

resource "aws_lb_listener_rule" "https" {
  for_each = var.https_listener_rules

  listener_arn = aws_lb_listener.https.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[each.value.target_group].arn
  }

  condition {
    host_header {
      values = each.value.host_headers
    }
  }
}
