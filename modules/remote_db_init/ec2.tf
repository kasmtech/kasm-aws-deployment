#######################################
##                                   ##
##        Ephemeral Init EC2         ##
##                                   ##
#######################################

## Single-use host that runs db_init_userdata.sh via cloud-init and self-terminates
## via `shutdown -h now` + instance_initiated_shutdown_behavior = "terminate".
## Runs in init mode (var.run_remote_db_init) or upgrade mode
## (var.run_remote_db_upgrade); the userdata branches on UPGRADE_REMOTE_DB.
##
## After a run the resource remains in TF state; lifecycle.ignore_changes = all
## prevents drift-triggered recreation on subsequent applies. Flip the active
## mode flag back to false to clean state.
##
## ignore_changes = all also swallows the Mode tag and user_data changes that a
## switch between init and upgrade mode (or a bump of the target release)
## produces. Without a replacement trigger an operator who flips init -> upgrade
## while the previous host is still in state gets a no-op apply and no upgrade
## job ever boots. The terraform_data below carries the job identity (mode +
## target release); replace_triggered_by forces a fresh host whenever it changes.
resource "terraform_data" "job_identity" {
  count = local.run_remote_db_init ? 1 : 0

  input = {
    mode         = var.run_remote_db_upgrade ? "upgrade" : "init"
    kasm_version = var.kasm_version
  }
}

resource "aws_instance" "initializer" {
  count = local.run_remote_db_init ? 1 : 0

  ami                                  = var.ami_id
  iam_instance_profile                 = module.role[0].instance_profile_name
  instance_initiated_shutdown_behavior = "terminate"
  instance_type                        = var.instance_type
  subnet_id                            = var.subnet_id
  user_data_base64                     = local.userdata
  vpc_security_group_ids               = [var.security_group_id]

  monitoring = true

  ## Upgrade mode stages a full pg_dump locally before the S3 upload, so the
  ## root volume must hold the backup, the release tarball and the installer's
  ## Docker images. Encrypted gp3, deleted with the instance.
  root_block_device {
    delete_on_termination = true
    encrypted             = true
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
  }

  tags = {
    Name = "${var.resource_name_prefix}-remote-db-init"
    Role = "remote-db-init"
    Mode = var.run_remote_db_upgrade ? "upgrade" : "init"
  }

  lifecycle {
    ignore_changes       = all
    replace_triggered_by = [terraform_data.job_identity]

    precondition {
      condition     = !(var.run_remote_db_init && var.run_remote_db_upgrade)
      error_message = "run_remote_db_init and run_remote_db_upgrade are mutually exclusive — the ephemeral host runs in exactly one mode."
    }
  }

  depends_on = [
    aws_ssm_parameter.status,
    time_sleep.iam_propagation
  ]
}
