#!/bin/bash

# Quick Start Script - Minimal setup for testing
# This creates a basic configuration with sensible defaults

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

echo -e "${GREEN}"
echo "⚡ Quick Start - AWS Static Site"
echo "==============================="
echo -e "${NC}"

# Show usage if help requested
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 <project-name> <domain> [subdomain]"
    echo ""
    echo "Examples:"
    echo "  $0 my-project example.com          # Creates my-project.example.com"
    echo "  $0 sample example.com sample     # Creates sample.example.com"
    echo "  $0 blog mydomain.com               # Creates blog.mydomain.com"
    echo ""
    echo "Arguments:"
    echo "  project-name  Name of the project (also used as subdomain if not specified)"
    echo "  domain        Your registered domain name"
    echo "  subdomain     Optional: specific subdomain (defaults to project-name)"
    exit 0
fi

# Get project name as argument or prompt
if [ -n "$1" ]; then
    PROJECT_NAME="$1"
else
    read -p "$(echo -e "${BLUE}Project name:${NC} ")" PROJECT_NAME
fi

# Get domain name as argument or prompt  
if [ -n "$2" ]; then
    DOMAIN_NAME="$2"
else
    read -p "$(echo -e "${BLUE}Domain name:${NC} ")" DOMAIN_NAME
fi

# Get subdomain as argument or use project name
if [ -n "$3" ]; then
    SUBDOMAIN="$3"
else
    SUBDOMAIN="$PROJECT_NAME"
fi

# Auto-detect AWS info
AWS_PROFILE=${AWS_PROFILE:-default}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text 2>/dev/null || echo "")
AWS_REGION=$(aws configure get region --profile "$AWS_PROFILE" 2>/dev/null || echo "us-east-1")

if [ -z "$AWS_ACCOUNT_ID" ]; then
    print_info "Could not detect AWS account. Make sure AWS CLI is configured."
    read -p "$(echo -e "${BLUE}AWS Account ID:${NC} ")" AWS_ACCOUNT_ID
fi

print_info "Using AWS Account: $AWS_ACCOUNT_ID"
print_info "Using AWS Region: $AWS_REGION"
print_info "Using AWS Profile: $AWS_PROFILE"

# Create minimal terraform.tfvars
cat > terraform.tfvars << EOF
# AWS Configuration
aws_account_id = "$AWS_ACCOUNT_ID"
aws_region     = "$AWS_REGION"
aws_profile    = "$AWS_PROFILE"

# Project Configuration
project_name = "$PROJECT_NAME"
environment  = "dev"

# Domain Configuration
domain_name     = "$DOMAIN_NAME"
subdomain       = "$SUBDOMAIN"
use_apex_domain = false

# SSL Certificate Configuration
create_certificate = true

# Static Site Configuration
enable_spa_routing = true

# Additional Tags
tags = {
  Owner       = "$USER"
  Team        = "Development"
  Environment = "dev"
}
EOF

print_success "Created terraform.tfvars with default settings"
print_info "Site will be available at: https://$SUBDOMAIN.$DOMAIN_NAME"
echo

# Ask about backend setup
read -p "$(echo -e "${BLUE}Setup Terraform backend? (Y/n):${NC} ")" setup_backend
if [[ ! "$setup_backend" =~ ^[Nn]$ ]]; then
    print_info "Setting up Terraform backend..."
    
    # Generate backend names
    BUCKET_NAME="terraform-state-$AWS_ACCOUNT_ID-$AWS_REGION"
    TABLE_NAME="terraform-state-lock"
    STATE_KEY="$PROJECT_NAME/terraform.tfstate"
    
    # Create S3 bucket
    if ! aws s3api head-bucket --bucket "$BUCKET_NAME" --profile "$AWS_PROFILE" 2>/dev/null; then
        print_info "Creating S3 bucket: $BUCKET_NAME"
        if [ "$AWS_REGION" = "us-east-1" ]; then
            aws s3api create-bucket --bucket "$BUCKET_NAME" --profile "$AWS_PROFILE"
        else
            aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE" --create-bucket-configuration LocationConstraint="$AWS_REGION"
        fi
        
        # Configure bucket
        aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --profile "$AWS_PROFILE" --versioning-configuration Status=Enabled
        aws s3api put-public-access-block --bucket "$BUCKET_NAME" --profile "$AWS_PROFILE" --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    fi
    
    # Create DynamoDB table
    if ! aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE" &>/dev/null; then
        print_info "Creating DynamoDB table: $TABLE_NAME"
        aws dynamodb create-table --table-name "$TABLE_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE" --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 > /dev/null
        aws dynamodb wait table-exists --table-name "$TABLE_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE"
    fi
    
    # Generate backend.tf
    cat > backend.tf << EOF
terraform {
  backend "s3" {
    bucket         = "$BUCKET_NAME"
    key            = "$STATE_KEY"
    region         = "$AWS_REGION"
    profile        = "$AWS_PROFILE"
    dynamodb_table = "$TABLE_NAME"
    encrypt        = true
  }
}
EOF
    
    print_success "Backend configured with state locking"
fi

echo
print_info "Next steps:"
echo "1. terraform init"
echo "2. terraform plan"  
echo "3. terraform apply"
echo
print_info "To customize settings, run: ./setup.sh"