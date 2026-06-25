resource "aws_instance" "this" {
  ami                         = var.ami_id
  associate_public_ip_address = var.is_public
  iam_instance_profile        = var.instance_profile_name
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  key_name                    = var.ssh_key_name
  user_data                   = var.user_data
  vpc_security_group_ids      = var.security_group_ids

  dynamic "root_block_device" {
    for_each = var.root_device

    content {
      delete_on_termination = root_block_device.value.delete
      encrypted             = root_block_device.value.encrypt_disk
      volume_size           = root_block_device.value.hdd_size
      volume_type           = root_block_device.value.volume_type
    }
  }

  dynamic "metadata_options" {
    for_each = length(var.metadata) > 0 ? [var.metadata] : []

    content {
      http_endpoint               = metadata_options.value.endpoint
      http_tokens                 = metadata_options.value.tokens
      http_put_response_hop_limit = metadata_options.value.hop_limit
      instance_metadata_tags      = metadata_options.value.tags
    }
  }

  monitoring = true

  tags = {
    Name = var.name
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

resource "aws_volume_attachment" "block_device" {
  device_name = "/dev/sdf"
  volume_id   = var.block_device_id
  instance_id = aws_instance.this.id
}
