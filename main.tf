terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # S3 backend configuration - configure this in terraform init or backend.tf
  # backend "s3" {
  #   bucket  = "your-terraform-state-bucket"
  #   key     = "static-site/terraform.tfstate"
  #   region  = "your-region"
  #   profile = "your-profile"
  # }
}

# Primary AWS provider
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
  
  dynamic "assume_role" {
    for_each = var.assume_role_arn != null ? [1] : []
    content {
      role_arn     = var.assume_role_arn
      session_name = "terraform-${var.project_name}-session"
    }
  }
  
  default_tags {
    tags = merge({
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }, var.tags)
  }
}

# US East 1 provider (required for CloudFront certificates)
provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
  profile = var.aws_profile
  
  dynamic "assume_role" {
    for_each = var.assume_role_arn != null ? [1] : []
    content {
      role_arn     = var.assume_role_arn
      session_name = "terraform-${var.project_name}-session-us-east-1"
    }
  }
  
  default_tags {
    tags = merge({
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }, var.tags)
  }
}

# Data sources
data "aws_caller_identity" "current" {}

# Route53 hosted zone
data "aws_route53_zone" "main" {
  name = "${var.domain_name}."
} 