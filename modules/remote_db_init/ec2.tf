#######################################
##                                   ##
##        Ephemeral Init EC2         ##
##                                   ##
#######################################

## Single-use host that runs db_init_userdata.sh via cloud-init and self-terminates
## via `shutdown -h now` + instance_initiated_shutdown_behavior = "terminate".
##
## After a successful run the resource remains in TF state pointing at a
## terminated instance; lifecycle.ignore_changes = all prevents recreation on
## subsequent applies. Flip var.run_remote_db_init back to false to clean state.
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

  tags = {
    Name = "${var.resource_name_prefix}-remote-db-init"
    Role = "remote-db-init"
  }

  lifecycle {
    ignore_changes = all
  }

  depends_on = [
    aws_ssm_parameter.status,
    time_sleep.iam_propagation
  ]
}
