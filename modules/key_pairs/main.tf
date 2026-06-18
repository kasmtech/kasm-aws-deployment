resource "aws_key_pair" "this" {
  count      = var.upload_key ? 1 : 0
  key_name   = var.key_name
  public_key = var.ssh_public_key
}

data "aws_key_pair" "this" {
  key_name = var.upload_key ? aws_key_pair.this[0].key_name : var.key_name
}

