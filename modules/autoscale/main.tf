## Create instance launch template
resource "aws_launch_template" "this" {
  name                   = var.name
  image_id               = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name
  ebs_optimized          = true
  update_default_version = true
  user_data              = var.user_data

  lifecycle {
    create_before_destroy = true
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    dynamic "ebs" {
      for_each = var.root_device

      content {
        delete_on_termination = ebs.value.delete
        encrypted             = true
        volume_size           = ebs.value.hdd_size
        volume_type           = ebs.value.volume_type
      }
    }
  }

  iam_instance_profile {
    name = var.instance_profile_name
  }

  dynamic "metadata_options" {
    for_each = length(var.metadata) > 0 ? [var.metadata] : []

    content {
      http_endpoint               = try(metadata_options.value.endpoint, "enabled")
      http_tokens                 = try(metadata_options.value.tokens, "optional")
      http_put_response_hop_limit = try(metadata_options.value.hop_limit, 1)
      instance_metadata_tags      = try(metadata_options.value.tags, null)
    }
  }

  monitoring {
    enabled = true
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = var.security_group_ids
  }

  tags = {
    Name        = "${var.system_role}-kasm-instance-config"
    Description = "Kasm ${var.system_role} instance Launch template for Kasm Autoscaler"
  }
}

## Create autlscale group
resource "aws_autoscaling_group" "this" {
  name_prefix               = var.scale_group_settings.name
  desired_capacity          = var.scale_group_settings.min_size
  min_size                  = var.scale_group_settings.min_size
  max_size                  = var.scale_group_settings.max_size
  vpc_zone_identifier       = var.scale_group_settings.subnet_ids
  health_check_grace_period = var.scale_group_settings.health_check_period
  default_cooldown          = var.scale_group_settings.cool_down_period
  health_check_type         = var.scale_group_settings.health_check_type #"ELB"

  launch_template {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [load_balancers, target_group_arns, tag]
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = var.scale_group_settings.min_health_percent
    }
  }

  tag {
    key                 = "Name"
    value               = lookup(var.scale_group_settings, "name", "${var.system_role}-kasm-autoscale")
    propagate_at_launch = true
  }
  tag {
    key                 = "Description"
    value               = "Kasm ${var.system_role} server Autoscaler group"
    propagate_at_launch = true
  }
}

## Create Autoscale policy
resource "aws_autoscaling_policy" "kasm_autoscale_cpu_policy" {
  name                      = lookup(var.scale_group_settings, "name", "${var.system_role}-kasm-cpu-scale-policy")
  policy_type               = var.scale_policy.policy_type
  estimated_instance_warmup = var.scale_policy.deploy_time
  autoscaling_group_name    = aws_autoscaling_group.this.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = var.scale_policy.metric_type
    }
    target_value = var.scale_policy.target_load
  }
}

## Attach Load Balancer Target groups
resource "aws_autoscaling_attachment" "this" {
  for_each = var.target_group_arns

  autoscaling_group_name = aws_autoscaling_group.this.name
  lb_target_group_arn    = each.value
}
