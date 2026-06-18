resource "aws_security_group_rule" "egress" {
  security_group_id = var.security_group_id
  description       = "Default egress rule"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}


