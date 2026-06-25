data "aws_caller_identity" "this" {
  provider = aws.regions[var.primary_region]
}

data "aws_ami" "instance" {
  for_each = local.all_regions

  most_recent = true
  name_regex  = var.vm_instance_lookups[(var.image_type)].image_regex
  owners      = [var.vm_instance_lookups[(var.image_type)].account_id]
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  provider = aws.regions[each.key]
}

data "aws_ami" "windows" {
  for_each = local.windows_regions

  most_recent = true
  name_regex  = var.vm_instance_lookups["windows"].image_regex
  owners      = [var.vm_instance_lookups["windows"].account_id]
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  provider = aws.regions[each.key]
}
