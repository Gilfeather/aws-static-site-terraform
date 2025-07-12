# Route53 record for static site domain (IPv4)
resource "aws_route53_record" "static_site" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.site_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.static_site.domain_name
    zone_id                = aws_cloudfront_distribution.static_site.hosted_zone_id
    evaluate_target_health = false
  }
}

# Route53 record for static site domain (IPv6)
resource "aws_route53_record" "static_site_ipv6" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.site_domain
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.static_site.domain_name
    zone_id                = aws_cloudfront_distribution.static_site.hosted_zone_id
    evaluate_target_health = false
  }
} 