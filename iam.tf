locals {
  iam_users = compact([
    "${local.standard_customer_name}-vm-autoscale-user",
    var.s3_persistent_profiles ? "${local.standard_customer_name}-s3-persisten-profiles-user" : "",
    var.s3_storage_provider ? "${local.standard_customer_name}-s3-storage-provider-user" : ""
  ])

  iam_groups = {
    "${local.standard_customer_name}-group" = {
      users    = local.iam_users
      policies = []
    }

    "${local.standard_customer_name}-autoscale-group" = {
      users    = ["${local.standard_customer_name}-vm-autoscale-user"]
      policies = [module.iam_policies["${local.standard_customer_name}-kasm-vm-autoscale"].arn]
    }
  }
  iam_policies = {
    "${local.standard_customer_name}-kasm-vm-autoscale" = local.kasm_vm_scale_policy
  }

  kasm_vm_scale_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "KasmAutoScaleGetInfo"
      Effect   = "Allow"
      Resource = "*"
      Action = [
        "kms:DescribeKey",
        "ec2:TerminateInstances",
        "ec2:DescribeVolumes",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeKeyPairs",
        "ec2:DescribeInstances",
        "ec2:DeleteTags",
        "ec2:CreateTags"
      ]
      }, {
      Effect = "Allow"
      Sid    = "AutoScaleKasmAgents"
      Action = [
        "ec2:RunInstances",
        "ec2:ImportKeyPair",
        "ec2:CreateKeyPair"
      ]
      Resource = [
        "arn:aws:ec2:*::image/*",
        "arn:aws:ec2:*:${data.aws_caller_identity.this.account_id}:volume/*",
        "arn:aws:ec2:*:${data.aws_caller_identity.this.account_id}:subnet/*",
        "arn:aws:ec2:*:${data.aws_caller_identity.this.account_id}:security-group/*",
        "arn:aws:ec2:*:${data.aws_caller_identity.this.account_id}:network-interface/*",
        "arn:aws:ec2:*:${data.aws_caller_identity.this.account_id}:key-pair/*",
        "arn:aws:ec2:*:${data.aws_caller_identity.this.account_id}:instance/*"
      ]
      }, {
      Sid    = "KMSEncryptionForEBS"
      Effect = "Allow"
      Action = [
        "kms:ReEncryptTo",
        "kms:ReEncryptFrom",
        "kms:Encrypt*",
        "kms:Decrypt",
        "kms:CreateGrant"
      ]
      Resource = [for region in local.all_regions : "arn:aws:kms:${region}:${data.aws_caller_identity.this.account_id}:key/${local.standard_customer_name}/kasm_agent_ebs"]
      },
      {
        Action = [
          "iam:PassRole"
        ],
        Effect = "Allow",
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.this.account_id}:role/${local.kasminit_role_name}"
        ]
      }
    ]
  })

  ssh_keys_to_create = [
    "bastion",
    (var.mgmt_ssh_key),
    "agent"
  ]
}

module "iam_users" {
  source   = "terraform-aws-modules/iam/aws//modules/iam-user"
  version  = "~> 5.0"
  for_each = toset(local.iam_users)

  name                          = each.key
  create_iam_user_login_profile = false
  create_iam_access_key         = true
  force_destroy                 = true

  providers = {
    aws = aws.regions[var.primary_region]
  }
}

## Create AWS DNS autoscale group - required for direct-to-agent
module "iam_groups" {
  source   = "terraform-aws-modules/iam/aws//modules/iam-group-with-policies"
  version  = "~> 5.0"
  for_each = local.iam_groups

  name                              = each.key
  group_users                       = each.value.users
  custom_group_policy_arns          = each.value.policies
  attach_iam_self_management_policy = false

  providers = {
    aws = aws.regions[var.primary_region]
  }
}

## Create AWS DNS autoscale policy - required for direct-to-agent
module "iam_policies" {
  source   = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version  = "~> 5.0"
  for_each = local.iam_policies

  name   = each.key
  policy = each.value

  providers = {
    aws = aws.regions[var.primary_region]
  }
}

data "aws_iam_policy_document" "kasminit" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [
      "arn:aws:secretsmanager:us-east-1:531489670392:secret:meta-secrets-BBHAK0",
      "arn:aws:secretsmanager:us-east-1:531489670392:secret:grafana-deploy-token-dR9GgV",
      "arn:aws:secretsmanager:us-east-1:531489670392:secret:wazuh-deploy-token-71W0kY"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt"
    ]
    resources = [
      "arn:aws:kms:us-east-1:531489670392:key/58092e19-1408-4308-a53c-9189ff707c4b"
    ]
  }

  provider = aws.regions[var.primary_region]
}

resource "aws_iam_policy" "kasminit" {
  name        = "${local.standard_customer_name}-kasm-init-policy"
  description = "Policy allowing Kasm services to start"
  policy      = data.aws_iam_policy_document.kasminit.json

  provider = aws.regions[var.primary_region]
}

module "kasminit_role" {
  source = "./modules/iam_role"

  role_name             = local.kasminit_role_name
  instance_profile_name = local.kasminit_instance_profile
  policy_arns = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    kasminit                     = aws_iam_policy.kasminit.arn
  }

  providers = {
    aws = aws.regions[var.primary_region]
  }
}

module "webapp_role" {
  source = "./modules/iam_role"

  role_name = "${local.standard_customer_name}-webapp-role"
  policy_arns = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    kasm_vm_autoscale            = module.iam_policies["${local.standard_customer_name}-kasm-vm-autoscale"].arn
    kasminit                     = aws_iam_policy.kasminit.arn
  }

  providers = {
    aws = aws.regions[var.primary_region]
  }
}

## Create SSH keys (where applicable)
module "ssh_keys" {
  source   = "./modules/ssh_keys"
  for_each = toset(local.ssh_keys_to_create)
}

module "upload_ssh_keys" {
  source   = "./modules/key_pairs"
  for_each = local.all_regions

  key_name       = local.mgmt_ssh_key_name
  upload_key     = true
  ssh_public_key = trimspace(module.ssh_keys[var.mgmt_ssh_key].ssh_key_info["public_key"])

  providers = {
    aws = aws.regions[each.key]
  }
}
