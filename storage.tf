locals {
  # TEMPORARILY uses empty maps during import phase - restore after subnets/SGs are imported
  # nfs_mount_target_settings = {
  #   for region in local.all_regions : region => {
  #     for subnet in local.public_agent_subnet_ids[region] : subnet => {
  #       subnet_id          = subnet
  #       security_group_ids = [module.vpc[region].security_group_ids["nfs-security-group"]]
  #     }
  #   }
  # }
  nfs_mount_target_settings   = { for region in local.all_regions : region => {} }
  s3_profile_bucket_base_name = var.s3_profile_bucket_base_name != "" ? var.s3_profile_bucket_base_name : "${local.standard_customer_name}-${var.primary_region}"
  s3_profile_policy_name      = var.aws_s3_persistent_profile_policy_name != "" ? "${var.primary_region}-${var.aws_s3_persistent_profile_policy_name}" : "${local.standard_customer_name}-${var.primary_region}-s3-profile-policy"
  s3_profile_policy = var.s3_persistent_profiles ? jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          module.s3_persistent_profile[0].bucket_arn,
          "${module.s3_persistent_profile[0].bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = module.s3_persistent_profile[0].bucket_arn
      }
    ]
  }) : ""

  s3_provider_bucket_base_name = var.s3_storage_provider_bucket_base_name != "" ? var.s3_storage_provider_bucket_base_name : "${local.standard_customer_name}-${var.primary_region}"
  s3_provider_bucket_arn       = var.s3_storage_provider ? module.s3_storage_provider[0].bucket_arn : ""
  s3_provider_bucket_name      = local.s3_provider_bucket_arn == "" ? "" : element(split(":", local.s3_provider_bucket_arn), length(local.s3_provider_bucket_arn))
  s3_profile_bucket_arn        = var.s3_persistent_profiles ? module.s3_persistent_profile[0].bucket_arn : ""
  s3_profile_bucket_name       = local.s3_profile_bucket_arn == "" ? "" : element(split(":", local.s3_profile_bucket_arn), length(local.s3_profile_bucket_arn))
  s3_provider_policy_name      = var.aws_s3_persistent_profile_policy_name != "" ? "${var.primary_region}-${var.aws_s3_storage_provider_policy_name}" : "${local.standard_customer_name}-${var.primary_region}-s3-storage-provider"
  s3_provider_policy = var.s3_storage_provider ? jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          module.s3_storage_provider[0].bucket_arn,
          "${module.s3_storage_provider[0].bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = module.s3_storage_provider[0].bucket_arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListAllBuckets"
        ]
      }
    ]
  }) : ""
}

module "nfs" {
  source = "./modules/efs"
  for_each = {
    for region in local.all_regions : region => region
    if var.deploy_nfs
  }

  efs_share_name        = "${each.key}-efs"
  is_encrypted          = true
  mount_target_settings = local.nfs_mount_target_settings[each.key]

  providers = {
    aws = aws.regions[each.key]
  }
}

## Deploy S3 bucket
module "s3_persistent_profile" {
  source = "./modules/s3_persistent_profile"
  count  = var.s3_persistent_profiles ? 1 : 0

  bucket_name                    = local.s3_profile_bucket_base_name
  persistent_profile_s3_user_arn = var.s3_persistent_profiles ? module.iam_users["${local.standard_customer_name}-s3-persisten-profiles-user"].iam_user_arn : null

  providers = {
    aws = aws.regions[var.primary_region]
  }
}

## Update IAM access policy for S3 bucket
module "s3_profile_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "~> 5.0"
  count   = var.s3_storage_provider ? 1 : 0

  name   = local.s3_profile_policy_name
  policy = local.s3_profile_policy

  providers = {
    aws = aws.regions[var.primary_region]
  }
}

## Update IAM policy attachment
module "s3_profile_attachment" {
  source = "./modules/iam_policy_attach"
  count  = var.s3_storage_provider ? 1 : 0

  group_name = var.s3_storage_provider ? module.iam_groups["${local.standard_customer_name}-group"].group_name : null
  policy_arn = module.s3_profile_policy[0].arn

  providers = {
    aws = aws.regions[var.primary_region]
  }
}

## Deploy Storage Provider S3 bucket
module "s3_storage_provider" {
  source = "./modules/s3_persistent_profile"
  count  = var.s3_storage_provider ? 1 : 0

  bucket_name                    = local.s3_provider_bucket_base_name
  persistent_profile_s3_user_arn = var.s3_storage_provider ? module.iam_users["${local.standard_customer_name}-s3-storage-provider-user"].iam_user_arn : null
  forward_logs                   = var.enable_s3_logging ? true : false
  s3_logging_bucket              = ""

  providers = {
    aws = aws.regions[var.primary_region]
  }
}

## Update IAM access policy for S3 bucket
module "s3_provider_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "~> 5.0"
  count   = var.s3_storage_provider ? 1 : 0

  name   = local.s3_provider_policy_name
  policy = local.s3_provider_policy

  providers = {
    aws = aws.regions[var.primary_region]
  }
}

## Update IAM policy attachment
module "s3_provider_attachment" {
  source = "./modules/iam_policy_attach"
  count  = var.s3_storage_provider ? 1 : 0

  group_name = var.s3_storage_provider ? module.iam_groups["${local.standard_customer_name}-group"].group_name : null
  policy_arn = module.s3_provider_policy[0].arn

  providers = {
    aws = aws.regions[var.primary_region]
  }
}

/*
 * Outputs
 */
output "s3_profile_bucket" {
  description = "AWS S3 bucket name for Management S3 persistent profile bucket"
  value       = local.s3_profile_bucket_name
}

output "s3_povider_bucket" {
  description = "AWS S3 bucket name for Management S3 persistent profile bucket"
  value       = local.s3_provider_bucket_name
}
