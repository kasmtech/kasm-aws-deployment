#######################################
##                                   ##
##              IAM                  ##
##                                   ##
#######################################

data "aws_iam_policy_document" "this" {
  count = local.run_remote_db_init ? 1 : 0

  statement {
    sid    = "ReadPreseedYAML"
    effect = "Allow"
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "arn:aws:s3:::${var.db_backup_bucket_name}/${local.preseed_s3_key}"
    ]
  }

  ## Upgrade mode only: the pre-upgrade pg_dump is copied to S3 so it outlives
  ## the self-terminating EC2. Scoped to the upgrades/ prefix; no reads/deletes.
  dynamic "statement" {
    for_each = var.run_remote_db_upgrade ? [1] : []
    content {
      sid    = "WritePreUpgradeBackupToS3"
      effect = "Allow"
      actions = [
        "s3:PutObject"
      ]
      resources = [
        "arn:aws:s3:::${var.db_backup_bucket_name}/${local.upgrade_backup_s3_prefix}/*"
      ]
    }
  }

  statement {
    sid    = "ReadKasmCredentialsFromSM"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [
      var.sm_system_cred_arn,
      var.sm_user_cred_arn,
      var.sm_admin_cred_arn
    ]
  }

  statement {
    sid    = "WriteInitStatusToSSM"
    effect = "Allow"
    actions = [
      "ssm:PutParameter"
    ]
    resources = [
      "arn:aws:ssm:${var.primary_region}:${var.aws_account_id}:parameter${local.ssm_status_param_name}"
    ]
  }
}

resource "aws_iam_policy" "this" {
  count = local.run_remote_db_init ? 1 : 0

  name        = "${var.resource_name_prefix}-remote-db-init"
  description = "Least-privilege policy for the one-shot Aurora preseed/upgrade EC2. Allows reading the preseed YAML from S3, fetching Kasm credentials from Secrets Manager, writing the success marker to SSM Parameter Store, and (upgrade mode only) uploading the pre-upgrade DB backup to S3."
  policy      = data.aws_iam_policy_document.this[0].json
}

## Deploys the IAM role + instance profile consumed by the ephemeral init host.
module "role" {
  source = "../iam_role"
  count  = local.run_remote_db_init ? 1 : 0

  role_name             = "${var.resource_name_prefix}-remote-db-init-role"
  instance_profile_name = "${var.resource_name_prefix}-remote-db-init-role"
  policy_arns = {
    ## Session Manager attach surface — lets operators `aws ssm start-session`
    ## into the init EC2 to debug a stalled installer before it self-terminates.
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    remote_db_init               = aws_iam_policy.this[0].arn
  }
}

## IAM is eventually-consistent: a newly-created role's policy attachments can
## take ~10-30s to propagate through STS. Without this buffer, the init EC2's
## SSM Agent makes its first RequestManagedInstanceRoleToken call before the
## policy is visible, gets AccessDenied, and falls through to the Default Host
## Management Configuration error path. Agent retries succeed on their own, but
## operators get a broken ~minute window where `aws ssm start-session` fails.
resource "time_sleep" "iam_propagation" {
  count = local.run_remote_db_init ? 1 : 0

  create_duration = "30s"

  depends_on = [
    module.role,
    aws_iam_policy.this
  ]
}
