#######################################
##                                   ##
##         Global Cluster            ##
##                                   ##
#######################################

resource "aws_rds_global_cluster" "this" {
  global_cluster_identifier = "${var.name}-global"
  engine                    = var.engine
  engine_version            = var.engine_version
  database_name             = var.database_name == "" ? null : var.database_name
  storage_encrypted         = true

  lifecycle {
    prevent_destroy = false
    ignore_changes  = [engine_version]
  }
}

#######################################
##                                   ##
##    Primary (Writer) Cluster       ##
##                                   ##
#######################################

resource "aws_rds_cluster" "primary" {
  cluster_identifier           = "${var.name}-${var.primary_region}"
  global_cluster_identifier    = aws_rds_global_cluster.this.id
  engine                       = var.engine
  engine_mode                  = var.engine_mode
  engine_version               = var.engine_version
  port                         = var.port
  db_subnet_group_name         = var.db_subnet_group_name
  vpc_security_group_ids       = var.vpc_security_group_ids
  master_username              = var.master_username
  master_password              = var.master_password
  storage_encrypted            = true
  kms_key_id                   = var.kms_key_id
  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window
  deletion_protection          = var.deletion_protection
  skip_final_snapshot          = var.skip_final_snapshot
  apply_immediately            = var.apply_immediately

  dynamic "serverlessv2_scaling_configuration" {
    for_each = length(var.serverlessv2_scaling_configuration) > 0 && var.engine_mode == "provisioned" ? [var.serverlessv2_scaling_configuration] : []

    content {
      max_capacity = serverlessv2_scaling_configuration.value.max_capacity
      min_capacity = serverlessv2_scaling_configuration.value.min_capacity
    }
  }

  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      #engine_version,
      availability_zones,
      master_username,
      master_password,
      global_cluster_identifier,
    ]
  }

  tags = {
    Name = "${var.name}-${var.primary_region}"
  }
}

resource "aws_rds_cluster_instance" "primary" {
  for_each = { for k, v in var.instances : k => v }

  apply_immediately            = try(each.value.apply_immediately, var.apply_immediately)
  auto_minor_version_upgrade   = try(each.value.auto_minor_version_upgrade, var.auto_minor_version_upgrade)
  availability_zone            = try(each.value.availability_zone, null)
  cluster_identifier           = aws_rds_cluster.primary.id
  db_subnet_group_name         = var.db_subnet_group_name
  engine                       = var.engine
  engine_version               = var.engine_version
  identifier                   = "${var.name}-${var.primary_region}-${each.key}"
  instance_class               = try(each.value.instance_class, var.instance_class)
  monitoring_interval          = try(each.value.monitoring_interval, var.monitoring_interval)
  performance_insights_enabled = var.performance_insights_enabled
  promotion_tier               = try(each.value.promotion_tier, 0)
  publicly_accessible          = var.publicly_accessible

  tags = {
    Name = "${var.name}-${var.primary_region}-${each.key}"
  }
}
