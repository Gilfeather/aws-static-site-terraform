# Environment information
output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "project_name" {
  description = "Project name"
  value       = var.project_name
}

# Static site outputs
output "site_url" {
  description = "Static site URL"
  value       = "https://${local.site_domain}"
}

output "site_domain" {
  description = "Static site domain name"
  value       = local.site_domain
}

output "s3_bucket_name" {
  description = "S3 bucket name for static site"
  value       = aws_s3_bucket.static_site.bucket
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.static_site.id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.static_site.domain_name
}

output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = data.aws_route53_zone.main.zone_id
}

output "certificate_arn" {
  description = "ACM certificate ARN"
  value       = local.certificate_arn
}

output "certificate_status" {
  description = "ACM certificate validation status"
  value       = var.create_certificate ? "ISSUED" : "EXISTING"
}

# Deployment information
output "deployment_info" {
  description = "Information for deployment scripts"
  value = {
    bucket_name      = aws_s3_bucket.static_site.bucket
    distribution_id  = aws_cloudfront_distribution.static_site.id
    site_url        = "https://${local.site_domain}"
    region          = var.aws_region
  }
}