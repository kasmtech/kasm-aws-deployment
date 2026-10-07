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
  description = "Status marker written by the ephemeral Aurora init/upgrade EC2. 'success:<ts>' = installer ran; 'skipped:already-initialized:<ts>' = sentinel table was already present; 'upgraded:<version>:<ts>' = upgrade flow completed; 'skipped:already-upgraded:<version>:<ts>' = marker already at target; 'failed:<stage>:<ts>' = upgrade aborted before touching the schema."
  type        = "String"
  value       = "pending"

  ## The EC2 mutates the value at runtime; ignore subsequent drift.
  lifecycle {
    ignore_changes = [value]
  }
}
