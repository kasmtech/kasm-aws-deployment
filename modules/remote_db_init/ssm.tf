#######################################
##                                   ##
##          Success-Signal           ##
##                                   ##
#######################################

## Placeholder parameter. The init EC2 overwrites the value via ssm:PutParameter
## on success ("success:<timestamp>") or on a skipped re-run ("skipped:...").
resource "aws_ssm_parameter" "status" {
  count = var.use_rds ? 1 : 0

  name        = local.ssm_status_param_name
  description = "Success/skip marker written by the ephemeral Aurora init EC2. 'success:<ts>' = installer ran; 'skipped:already-initialized:<ts>' = sentinel table was already present."
  type        = "String"
  value       = "pending"

  ## The EC2 mutates the value at runtime; ignore subsequent drift.
  lifecycle {
    ignore_changes = [value]
  }
}
