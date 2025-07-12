# CloudFront Function for Security Headers (無料)
resource "aws_cloudfront_function" "security_headers" {
  count   = var.enable_security_headers ? 1 : 0
  name    = "${var.project_name}-${var.environment}-security-headers"
  runtime = "cloudfront-js-1.0"
  comment = "Add security headers to responses"
  publish = true
  code    = file("${path.module}/security-headers.js")
}

# Enhanced S3 Bucket Policy with additional security
resource "aws_s3_bucket_policy" "static_site_enhanced" {
  count  = var.enable_enhanced_s3_policy ? 1 : 0
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
      },
      {
        Sid    = "DenyInsecureConnections"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.static_site.arn,
          "${aws_s3_bucket.static_site.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "DenyOldTLSVersions"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.static_site.arn,
          "${aws_s3_bucket.static_site.arn}/*"
        ]
        Condition = {
          NumericLessThan = {
            "s3:TlsVersion" = "1.2"
          }
        }
      }
    ]
  })
}

# CloudWatch Log Group for monitoring (無料範囲内)
resource "aws_cloudwatch_log_group" "static_site" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/cloudfront/${var.project_name}-${var.environment}"
  retention_in_days = 7  # 無料範囲で短期保持
}

# CloudWatch Metric Alarm for basic monitoring (無料範囲内)
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  count               = var.enable_basic_monitoring ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = "300"
  statistic           = "Average"
  threshold           = "10"
  alarm_description   = "This metric monitors 4xx error rate"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DistributionId = aws_cloudfront_distribution.static_site.id
  }
}

# S3 Bucket Notification for monitoring (無料)
# Note: S3 notifications to EventBridge are free
resource "aws_s3_bucket_notification" "static_site" {
  count  = var.enable_s3_notifications ? 1 : 0
  bucket = aws_s3_bucket.static_site.id

  # EventBridge integration (無料)
  eventbridge = var.enable_s3_notifications
}

# EventBridge rule for S3 events (無料範囲内)
resource "aws_cloudwatch_event_rule" "s3_events" {
  count       = var.enable_s3_notifications ? 1 : 0
  name        = "${var.project_name}-${var.environment}-s3-events"
  description = "Capture S3 bucket events"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created", "Object Deleted"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.static_site.bucket]
      }
    }
  })
}

# CloudWatch Log Group as EventBridge target (無料範囲内)
resource "aws_cloudwatch_event_target" "s3_logs" {
  count     = var.enable_s3_notifications ? 1 : 0
  rule      = aws_cloudwatch_event_rule.s3_events[0].name
  target_id = "S3EventsLogTarget"
  arn       = aws_cloudwatch_log_group.static_site[0].arn
}