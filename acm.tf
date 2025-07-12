# ACM Certificate for the static site
resource "aws_acm_certificate" "static_site" {
  count    = var.create_certificate ? 1 : 0
  provider = aws.us_east_1  # CloudFront requires certificates in us-east-1
  
  domain_name               = local.site_domain
  subject_alternative_names = var.certificate_alternative_names
  validation_method         = "DNS"
  
  lifecycle {
    create_before_destroy = true
  }
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-cert"
  })
}

# Route53 records for certificate validation
resource "aws_route53_record" "certificate_validation" {
  provider = aws.us_east_1
  
  for_each = var.create_certificate ? {
    for dvo in aws_acm_certificate.static_site[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}
  
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

# Certificate validation
resource "aws_acm_certificate_validation" "static_site" {
  count    = var.create_certificate ? 1 : 0
  provider = aws.us_east_1
  
  certificate_arn         = aws_acm_certificate.static_site[0].arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation : record.fqdn]
  
  timeouts {
    create = "10m"
  }
}