# AWS Configuration
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "AWS Account ID must be a 12-digit number."
  }
}

variable "aws_profile" {
  description = "AWS profile to use for authentication"
  type        = string
  default     = "default"
}

variable "assume_role_arn" {
  description = "ARN of the IAM role to assume (optional)"
  type        = string
  default     = null
}

variable "terraform_state_bucket" {
  description = "S3 bucket for Terraform state"
  type        = string
  default     = null
}

variable "terraform_state_key" {
  description = "S3 key for Terraform state"
  type        = string
  default     = "terraform.tfstate"
}

# Project Configuration
variable "project_name" {
  description = "Project name (used for resource naming)"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

# Domain Configuration
variable "domain_name" {
  description = "Base domain name (e.g., example.com)"
  type        = string
}

variable "subdomain" {
  description = "Subdomain for the static site (e.g., 'app' for app.example.com)"
  type        = string
  default     = "app"
}

variable "use_apex_domain" {
  description = "Whether to use the apex domain (true) or subdomain (false)"
  type        = bool
  default     = false
}

variable "certificate_alternative_names" {
  description = "Alternative domain names for the SSL certificate"
  type        = list(string)
  default     = []
}

variable "create_certificate" {
  description = "Whether to create a new ACM certificate or use an existing one"
  type        = bool
  default     = true
}

variable "existing_certificate_arn" {
  description = "ARN of existing ACM certificate (used when create_certificate is false)"
  type        = string
  default     = null
}

# Static Site Configuration
variable "default_root_object" {
  description = "Default root object for CloudFront"
  type        = string
  default     = "index.html"
}

variable "error_page_path" {
  description = "Path to error page (for SPA routing)"
  type        = string
  default     = "/index.html"
}

variable "enable_spa_routing" {
  description = "Enable SPA routing (redirects 404/403 to index.html)"
  type        = bool
  default     = true
}

variable "cache_default_ttl" {
  description = "Default TTL for CloudFront cache in seconds"
  type        = number
  default     = 3600
}

variable "cache_max_ttl" {
  description = "Maximum TTL for CloudFront cache in seconds"
  type        = number
  default     = 86400
}

variable "enable_compression" {
  description = "Enable CloudFront compression"
  type        = bool
  default     = true
}

variable "price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"
  
  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.price_class)
    error_message = "Price class must be one of: PriceClass_All, PriceClass_200, PriceClass_100."
  }
}

# Security Configuration
variable "enable_s3_versioning" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = true
}

variable "s3_encryption_algorithm" {
  description = "S3 server-side encryption algorithm"
  type        = string
  default     = "AES256"
  
  validation {
    condition     = contains(["AES256", "aws:kms"], var.s3_encryption_algorithm)
    error_message = "Encryption algorithm must be either AES256 or aws:kms."
  }
}

variable "minimum_protocol_version" {
  description = "Minimum SSL/TLS protocol version for CloudFront"
  type        = string
  default     = "TLSv1.2_2021"
}

variable "geo_restriction_type" {
  description = "Type of geo restriction (none, whitelist, blacklist)"
  type        = string
  default     = "none"
  
  validation {
    condition     = contains(["none", "whitelist", "blacklist"], var.geo_restriction_type)
    error_message = "Geo restriction type must be one of: none, whitelist, blacklist."
  }
}

variable "geo_restriction_locations" {
  description = "List of country codes for geo restriction"
  type        = list(string)
  default     = []
}

# Tags
variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
} 