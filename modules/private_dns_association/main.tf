resource "aws_route53_zone_association" "this" {
  zone_id = var.zone_id
  vpc_id  = var.vpc_id
}

