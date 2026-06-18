data "aws_iam_policy_document" "db_backup" {
  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [
      "arn:aws:s3:::${var.db_backup_bucket_name}"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListMultipartUploadParts",
      "s3:AbortMultipartUpload"
    ]
    resources = [
      "arn:aws:s3:::${var.db_backup_bucket_name}/*"
    ]
  }
}

resource "aws_iam_policy" "db_backup" {
  name        = "${var.customer_name}-db-backup-policy"
  description = "Policy allowing Kasm DB to backup"
  policy      = data.aws_iam_policy_document.db_backup.json
}

module "db_backup_role" {
  source = "../iam_role"

  role_name             = "${var.resource_name_prefix}-db-backup-role"
  instance_profile_name = "${var.resource_name_prefix}-db-backup-role"
  policy_arns = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    db_backup                    = aws_iam_policy.db_backup.arn
    kasminit                     = var.kasminit_policy_arn
  }
}

resource "aws_ebs_volume" "db_block_device" {
  availability_zone = var.availability_zone
  encrypted         = true
  size              = var.db_block_volume_size

  tags = {
    Name = "db-block-device"
  }
}

module "database_instance" {
  source = "../instance"

  ami_id                = var.ami_id
  block_device_id       = aws_ebs_volume.db_block_device.id
  instance_profile_name = module.db_backup_role.instance_profile_name
  instance_type         = var.db_instance_type
  name                  = "${var.customer_name}-db"
  security_group_ids    = var.security_group_ids
  ssh_key_name          = var.ssh_key_name
  subnet_id             = var.subnet_id
  user_data             = var.user_data
}
