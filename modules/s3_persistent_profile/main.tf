locals {
  bucket_base_name = var.bucket_base_name != "" ? var.bucket_base_name : var.project_name != "" ? var.project_name : var.bucket_name
}

resource "aws_s3_bucket" "s3_bucket" {
  bucket_prefix = local.bucket_base_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "block_public" {
  bucket                  = aws_s3_bucket.s3_bucket.bucket
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.s3_bucket.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_logging" "logging" {
  count = var.forward_logs ? 0 : 0

  bucket        = aws_s3_bucket.s3_bucket.bucket
  target_bucket = var.s3_logging_bucket
  target_prefix = var.s3_target_log_folder
}

resource "aws_s3_bucket_intelligent_tiering_configuration" "bucket_tiering" {
  bucket = aws_s3_bucket.s3_bucket.id
  name   = "PersistentProfileBucketTiering"

  dynamic "tiering" {
    for_each = var.tiering_config
    content {
      access_tier = tiering.value.access_tier
      days        = tiering.value.days
    }
  }
}

resource "aws_s3_bucket_policy" "s3_policy" {
  bucket = aws_s3_bucket.s3_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "PolicyForAllowKasmS3UserAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.persistent_profile_s3_user_arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "${aws_s3_bucket.s3_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encrypt_bucket" {
  bucket = aws_s3_bucket.s3_bucket.bucket

  rule {
    bucket_key_enabled = true
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_id
      sse_algorithm     = var.kms_key_id != "" ? "aws:kms" : "AES256"
    }
  }
}



