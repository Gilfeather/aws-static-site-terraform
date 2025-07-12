# S3 bucket for static site
resource "aws_s3_bucket" "static_site" {
  bucket = "${var.project_name}-${var.environment}-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
}

resource "aws_s3_bucket_public_access_block" "static_site" {
  bucket = aws_s3_bucket.static_site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "static_site" {
  count  = var.enable_s3_versioning ? 1 : 0
  bucket = aws_s3_bucket.static_site.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "static_site" {
  bucket = aws_s3_bucket.static_site.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = var.s3_encryption_algorithm
    }
  }
}

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "static_site" {
  name                              = "${var.project_name}-${var.environment}-static-site-oac"
  description                       = "Origin Access Control for ${var.project_name} Static Site"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Local values for domain configuration
locals {
  site_domain = var.use_apex_domain ? var.domain_name : "${var.subdomain}.${var.domain_name}"
}

# Data source for existing SSL certificate (when not creating new one)
data "aws_acm_certificate" "existing" {
  count    = var.create_certificate ? 0 : 1
  provider = aws.us_east_1
  domain   = local.site_domain
  statuses = ["ISSUED"]
  most_recent = true
}

# Local value for certificate ARN
locals {
  certificate_arn = var.create_certificate ? aws_acm_certificate_validation.static_site[0].certificate_arn : (
    var.existing_certificate_arn != null ? var.existing_certificate_arn : data.aws_acm_certificate.existing[0].arn
  )
}

# CloudFront distribution for static site
resource "aws_cloudfront_distribution" "static_site" {
  origin {
    domain_name              = aws_s3_bucket.static_site.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.static_site.id
    origin_id                = "S3-${aws_s3_bucket.static_site.bucket}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = var.default_root_object
  comment             = "${var.project_name} Static Site Distribution"
  price_class         = var.price_class

  aliases = [local.site_domain]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.static_site.bucket}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = var.cache_default_ttl
    max_ttl                = var.cache_max_ttl
    compress               = var.enable_compression
  }

  # Error pages for SPA routing (conditional)
  dynamic "custom_error_response" {
    for_each = var.enable_spa_routing ? [1] : []
    content {
      error_code         = 404
      response_code      = 200
      response_page_path = var.error_page_path
    }
  }

  dynamic "custom_error_response" {
    for_each = var.enable_spa_routing ? [1] : []
    content {
      error_code         = 403
      response_code      = 200
      response_page_path = var.error_page_path
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type
      locations        = var.geo_restriction_locations
    }
  }

  viewer_certificate {
    acm_certificate_arn      = local.certificate_arn
    minimum_protocol_version = var.minimum_protocol_version
    ssl_support_method       = "sni-only"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-static-site"
  })
}

# S3 bucket policy for CloudFront OAC
resource "aws_s3_bucket_policy" "static_site" {
  bucket = aws_s3_bucket.static_site.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.static_site.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.static_site.arn
          }
        }
      }
    ]
  })
} 