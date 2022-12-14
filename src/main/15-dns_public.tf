# DNS Zone
module "dns_zone" {
  source  = "terraform-aws-modules/route53/aws//modules/zones"
  version = "~> 2.0"

  zones = var.public_dns_zones
}

resource "aws_route53_record" "cms" {
  zone_id = module.dns_zone.route53_zone_zone_id[keys(var.public_dns_zones)[0]]
  name    = "cms"
  type    = "CNAME"
  records = [module.alb_cms.lb_dns_name]
  ttl     = var.dns_record_ttl
}


## Preview website
/*
resource "aws_route53_record" "preview" {
  zone_id = module.dns_zone.route53_zone_zone_id[keys(var.public_dns_zones)[0]]
  name    = "preview"
  type    = "CNAME"
  records = [aws_cloudfront_distribution.preview.domain_name]
  ttl     = var.dns_record_ttl
}
*/

## Public website
resource "aws_route53_record" "website" {
  zone_id = module.dns_zone.route53_zone_zone_id[keys(var.public_dns_zones)[0]]
  name    = ""
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}


/*
resource "aws_route53_record" "www" {
  count   = var.public_dns_zones == null ? 0 : 1
  zone_id = module.dns_zone[0].route53_zone_zone_id[keys(var.public_dns_zones)[0]]
  name    = "www"
  type    = "CNAME"
  ttl     = var.dns_record_ttl

  weighted_routing_policy {
    weight = 90
  }

  set_identifier = "live"
  records        = [aws_cloudfront_distribution.website.domain_name]
}

*/

resource "aws_route53_record" "pn" {
  for_each = { for r in var.pn_dns_records : r.name => r }
  zone_id  = module.dns_zone.route53_zone_zone_id[keys(var.public_dns_zones)[0]]
  name     = each.key
  type     = each.value.type
  records  = [each.value.value]
  ttl      = var.dns_record_ttl
}