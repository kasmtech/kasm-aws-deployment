#######################################
##                                   ##
##  Secondary (Reader) Cluster       ##
##                                   ##
#######################################

resource "aws_rds_cluster" "this" {
  cluster_identifier             = "${var.name}-${var.region}"
  global_cluster_identifier      = var.global_cluster_id
  source_region                  = var.source_region
  engine                         = var.engine
  engine_mode                    = var.engine_mode
  engine_version                 = var.engine_version
  port                           = var.port
  db_subnet_group_name           = var.db_subnet_group_name
  vpc_security_group_ids         = var.vpc_security_group_ids
  storage_encrypted              = true
  kms_key_id                     = var.kms_key_id
  backup_retention_period        = var.backup_retention_period
  preferred_backup_window        = var.preferred_backup_window
  preferred_maintenance_window   = var.preferred_maintenance_window
  deletion_protection            = var.deletion_protection
  skip_final_snapshot            = var.skip_final_snapshot
  apply_immediately              = var.apply_immediately
  enable_global_write_forwarding = var.enable_write_forwarding

  lifecycle {
    ignore_changes = [
      engine_version,
      availability_zones,
      global_cluster_identifier,
      replication_source_identifier,
    ]
  }

  tags = {
    Name = "${var.name}-${var.region}"
  }
}

resource "aws_rds_cluster_instance" "this" {
  for_each = { for k, v in var.instances : k => v }

  apply_immediately            = try(each.value.apply_immediately, var.apply_immediately)
  auto_minor_version_upgrade   = try(each.value.auto_minor_version_upgrade, var.auto_minor_version_upgrade)
  cluster_identifier           = aws_rds_cluster.this.id
  db_subnet_group_name         = var.db_subnet_group_name
  engine                       = var.engine
  engine_version               = var.engine_version
  identifier                   = "${var.name}-${var.region}-${each.key}"
  instance_class               = try(each.value.instance_class, var.instance_class)
  monitoring_interval          = try(each.value.monitoring_interval, var.monitoring_interval)
  performance_insights_enabled = var.performance_insights_enabled
  promotion_tier               = try(each.value.promotion_tier, 0)
  publicly_accessible          = var.publicly_accessible

  tags = {
    Name = "${var.name}-${var.region}-${each.key}"
  }
}