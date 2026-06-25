resource "aws_efs_file_system" "this" {
  creation_token = var.efs_share_name
  encrypted      = var.is_encrypted
  kms_key_id     = var.kms_key_id

  lifecycle_policy {
    transition_to_ia = "AFTER_60_DAYS"
  }
  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  tags = {
    Name = var.efs_share_name
  }

  lifecycle { ignore_changes = [creation_token] }
}

# TEMPORARILY COMMENTED OUT during import phase - uncomment after VPCs/subnets are imported
# resource "aws_efs_mount_target" "this" {
#   for_each = var.mount_target_settings
#
#   file_system_id  = aws_efs_file_system.this.id
#   subnet_id       = each.value.subnet_id
#   security_groups = each.value.security_group_ids
# }

resource "aws_efs_backup_policy" "this" {
  file_system_id = aws_efs_file_system.this.id

  backup_policy {
    status = "ENABLED"
  }
}
