data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

locals {
  zone_id = data.aws_route53_zone.main.zone_id
}
