#!/bin/bash

# AWS Static Site Terraform Setup Script
# This script helps you configure terraform.tfvars interactively

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to prompt user input with default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local variable_name="$3"
    
    if [ -n "$default" ]; then
        read -p "$(echo -e "${BLUE}$prompt${NC} [${YELLOW}$default${NC}]: ")" input
        eval "$variable_name=\"\${input:-$default}\""
    else
        read -p "$(echo -e "${BLUE}$prompt${NC}: ")" input
        eval "$variable_name=\"$input\""
    fi
}

# Function to validate required field
validate_required() {
    local value="$1"
    local field_name="$2"
    
    if [ -z "$value" ]; then
        print_error "$field_name is required!"
        exit 1
    fi
}

# Function to validate AWS Account ID format
validate_aws_account_id() {
    local account_id="$1"
    if [[ ! "$account_id" =~ ^[0-9]{12}$ ]]; then
        print_error "AWS Account ID must be 12 digits!"
        exit 1
    fi
}

# Function to validate project name format
validate_project_name() {
    local project_name="$1"
    if [[ ! "$project_name" =~ ^[a-z0-9-]+$ ]]; then
        print_error "Project name must contain only lowercase letters, numbers, and hyphens!"
        exit 1
    fi
}

# Function to get AWS account ID automatically
get_aws_account_id() {
    local account_id
    if command -v aws &> /dev/null; then
        local profile=${AWS_PROFILE:-default}
        account_id=$(aws sts get-caller-identity --profile "$profile" --query Account --output text 2>/dev/null || echo "")
        if [ -n "$account_id" ]; then
            print_info "Detected AWS Account ID: $account_id"
            echo "$account_id"
        fi
    fi
}

# Function to get AWS region automatically
get_aws_region() {
    local region
    if command -v aws &> /dev/null; then
        local profile=${AWS_PROFILE:-default}
        region=$(aws configure get region --profile "$profile" 2>/dev/null || echo "")
        if [ -n "$region" ]; then
            print_info "Detected AWS Region: $region"
            echo "$region"
        fi
    fi
}

# Function to get AWS profile automatically
get_aws_profile() {
    local profile
    profile=${AWS_PROFILE:-default}
    print_info "Current AWS Profile: $profile"
    echo "$profile"
}

# Function to list Route53 hosted zones
list_hosted_zones() {
    if command -v aws &> /dev/null; then
        print_info "Available Route53 hosted zones:"
        local profile=${AWS_PROFILE:-default}
        aws route53 list-hosted-zones --profile "$profile" --query 'HostedZones[].Name' --output table 2>/dev/null || {
            print_warning "Could not list hosted zones. Make sure you have Route53 permissions."
        }
    fi
}

# Main setup function
main() {
    echo -e "${GREEN}"
    echo "🚀 AWS Static Site Terraform Setup"
    echo "=================================="
    echo -e "${NC}"
    
    print_info "This script will help you create terraform.tfvars configuration file."
    echo
    
    # Check if terraform.tfvars already exists
    if [ -f "terraform.tfvars" ]; then
        print_warning "terraform.tfvars already exists!"
        read -p "$(echo -e "${YELLOW}Do you want to overwrite it? (y/N):${NC} ")" overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            print_info "Setup cancelled."
            exit 0
        fi
    fi
    
    echo
    print_info "=== AWS Configuration ==="
    
    # AWS Account ID
    auto_account_id=$(get_aws_account_id)
    prompt_with_default "AWS Account ID" "$auto_account_id" "aws_account_id"
    validate_required "$aws_account_id" "AWS Account ID"
    validate_aws_account_id "$aws_account_id"
    
    # AWS Region
    auto_region=$(get_aws_region)
    prompt_with_default "AWS Region" "${auto_region:-us-east-1}" "aws_region"
    validate_required "$aws_region" "AWS Region"
    
    # AWS Profile
    auto_profile=$(get_aws_profile)
    prompt_with_default "AWS Profile" "$auto_profile" "aws_profile"
    validate_required "$aws_profile" "AWS Profile"
    
    # IAM Role (optional)
    prompt_with_default "IAM Role ARN to assume (optional)" "" "assume_role_arn"
    
    echo
    print_info "=== Project Configuration ==="
    
    # Project Name
    prompt_with_default "Project name (lowercase, alphanumeric with hyphens)" "" "project_name"
    validate_required "$project_name" "Project name"
    validate_project_name "$project_name"
    
    # Environment
    prompt_with_default "Environment" "dev" "environment"
    validate_required "$environment" "Environment"
    
    echo
    print_info "=== Domain Configuration ==="
    
    # List hosted zones
    list_hosted_zones
    echo
    
    # Domain Name
    prompt_with_default "Domain name (e.g., example.com)" "" "domain_name"
    validate_required "$domain_name" "Domain name"
    
    # Subdomain or Apex
    read -p "$(echo -e "${BLUE}Use apex domain ($domain_name) instead of subdomain? (y/N):${NC} ")" use_apex
    if [[ "$use_apex" =~ ^[Yy]$ ]]; then
        use_apex_domain="true"
        subdomain=""
    else
        use_apex_domain="false"
        prompt_with_default "Subdomain" "app" "subdomain"
        validate_required "$subdomain" "Subdomain"
    fi
    
    echo
    print_info "=== SSL Certificate Configuration ==="
    
    # Certificate creation
    read -p "$(echo -e "${BLUE}Create new SSL certificate automatically? (Y/n):${NC} ")" create_cert
    if [[ "$create_cert" =~ ^[Nn]$ ]]; then
        create_certificate="false"
        prompt_with_default "Existing certificate ARN" "" "existing_certificate_arn"
        validate_required "$existing_certificate_arn" "Certificate ARN"
    else
        create_certificate="true"
        existing_certificate_arn=""
    fi
    
    echo
    print_info "=== Additional Configuration ==="
    
    # SPA Routing
    read -p "$(echo -e "${BLUE}Enable Single Page Application (SPA) routing? (Y/n):${NC} ")" enable_spa
    if [[ "$enable_spa" =~ ^[Nn]$ ]]; then
        enable_spa_routing="false"
    else
        enable_spa_routing="true"
    fi
    
    # S3 Versioning
    read -p "$(echo -e "${BLUE}Enable S3 versioning? (Y/n):${NC} ")" enable_versioning
    if [[ "$enable_versioning" =~ ^[Nn]$ ]]; then
        enable_s3_versioning="false"
    else
        enable_s3_versioning="true"
    fi
    
    # CloudFront Price Class
    echo
    print_info "CloudFront Price Classes:"
    echo "  1. PriceClass_100 (US, Canada, Europe)"
    echo "  2. PriceClass_200 (US, Canada, Europe, Asia, Middle East, Africa)"
    echo "  3. PriceClass_All (All edge locations)"
    read -p "$(echo -e "${BLUE}Choose price class (1-3):${NC} ")" price_choice
    case $price_choice in
        1) price_class="PriceClass_100" ;;
        2) price_class="PriceClass_200" ;;
        3) price_class="PriceClass_All" ;;
        *) price_class="PriceClass_100" ;;
    esac
    
    # Tags
    prompt_with_default "Owner name" "$USER" "owner_name"
    prompt_with_default "Team name" "Development" "team_name"
    
    echo
    print_info "=== Backend Configuration ==="
    
    # Backend setup
    read -p "$(echo -e "${BLUE}Setup Terraform backend (S3 + DynamoDB)? (Y/n):${NC} ")" setup_backend
    if [[ ! "$setup_backend" =~ ^[Nn]$ ]]; then
        setup_backend="true"
        
        # Get AWS account ID for unique naming
        aws_account_id_detected=$(aws sts get-caller-identity --profile "$aws_profile" --query Account --output text 2>/dev/null || echo "")
        if [ -n "$aws_account_id_detected" ]; then
            default_bucket="terraform-state-$aws_account_id_detected-$aws_region"
        else
            default_bucket="terraform-state-$aws_account_id-$aws_region"
        fi
        
        prompt_with_default "S3 bucket name for Terraform state" "$default_bucket" "terraform_state_bucket"
        prompt_with_default "DynamoDB table name for state locking" "terraform-state-lock" "terraform_lock_table"
        prompt_with_default "Terraform state key" "$project_name/terraform.tfstate" "terraform_state_key"
    else
        setup_backend="false"
    fi
    
    echo
    print_info "=== Generating terraform.tfvars ==="
    
    # Generate terraform.tfvars file
    cat > terraform.tfvars << EOF
# AWS Configuration
aws_account_id = "$aws_account_id"
aws_region     = "$aws_region"
aws_profile    = "$aws_profile"
$([ -n "$assume_role_arn" ] && echo "assume_role_arn = \"$assume_role_arn\"")

# Project Configuration
project_name = "$project_name"
environment  = "$environment"

# Domain Configuration
domain_name     = "$domain_name"
$([ "$use_apex_domain" = "false" ] && echo "subdomain       = \"$subdomain\"")
use_apex_domain = $use_apex_domain

# SSL Certificate Configuration
create_certificate = $create_certificate
$([ -n "$existing_certificate_arn" ] && echo "existing_certificate_arn = \"$existing_certificate_arn\"")

# Static Site Configuration
enable_spa_routing = $enable_spa_routing

# CloudFront Configuration
price_class = "$price_class"

# Security Configuration
enable_s3_versioning = $enable_s3_versioning

# Additional Tags
tags = {
  Owner       = "$owner_name"
  Team        = "$team_name"
  Environment = "$environment"
}
EOF
    
    print_success "terraform.tfvars has been created successfully!"
    echo
    
    # Setup backend if requested
    if [ "$setup_backend" = "true" ]; then
        print_info "=== Setting up Terraform Backend ==="
        
        # Create backend resources
        print_info "Creating S3 bucket and DynamoDB table..."
        
        # Create S3 bucket
        if ! aws s3api head-bucket --bucket "$terraform_state_bucket" --profile "$aws_profile" 2>/dev/null; then
            print_info "Creating S3 bucket: $terraform_state_bucket"
            if [ "$aws_region" = "us-east-1" ]; then
                aws s3api create-bucket --bucket "$terraform_state_bucket" --profile "$aws_profile"
            else
                aws s3api create-bucket --bucket "$terraform_state_bucket" --region "$aws_region" --profile "$aws_profile" --create-bucket-configuration LocationConstraint="$aws_region"
            fi
            
            # Configure bucket
            aws s3api put-bucket-versioning --bucket "$terraform_state_bucket" --profile "$aws_profile" --versioning-configuration Status=Enabled
            aws s3api put-bucket-encryption --bucket "$terraform_state_bucket" --profile "$aws_profile" --server-side-encryption-configuration '{
                "Rules": [
                    {
                        "ApplyServerSideEncryptionByDefault": {
                            "SSEAlgorithm": "AES256"
                        }
                    }
                ]
            }'
            aws s3api put-public-access-block --bucket "$terraform_state_bucket" --profile "$aws_profile" --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
        else
            print_info "S3 bucket $terraform_state_bucket already exists"
        fi
        
        # Create DynamoDB table
        if ! aws dynamodb describe-table --table-name "$terraform_lock_table" --region "$aws_region" --profile "$aws_profile" &>/dev/null; then
            print_info "Creating DynamoDB table: $terraform_lock_table"
            aws dynamodb create-table --table-name "$terraform_lock_table" --region "$aws_region" --profile "$aws_profile" --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
            
            print_info "Waiting for DynamoDB table to be active..."
            aws dynamodb wait table-exists --table-name "$terraform_lock_table" --region "$aws_region" --profile "$aws_profile"
        else
            print_info "DynamoDB table $terraform_lock_table already exists"
        fi
        
        # Generate backend.tf
        cat > backend.tf << EOF
terraform {
  backend "s3" {
    bucket         = "$terraform_state_bucket"
    key            = "$terraform_state_key"
    region         = "$aws_region"
    profile        = "$aws_profile"
    dynamodb_table = "$terraform_lock_table"
    encrypt        = true
  }
}
EOF
        
        print_success "Backend configuration created: backend.tf"
    fi
    
    echo
    # Show next steps
    print_info "=== Next Steps ==="
    if [ "$setup_backend" = "true" ]; then
        echo "1. Review the generated terraform.tfvars and backend.tf files"
        echo "2. Run: terraform init"
        echo "3. When prompted about state migration, type 'yes' if you have existing state"
        echo "4. Run: terraform plan"
        echo "5. Run: terraform apply"
    else
        echo "1. Review the generated terraform.tfvars file"
        echo "2. (Optional) Setup backend: ./bootstrap-backend.sh"
        echo "3. Run: terraform init"
        echo "4. Run: terraform plan"
        echo "5. Run: terraform apply"
    fi
    echo
    
    if [ "$create_certificate" = "true" ]; then
        print_info "Note: SSL certificate will be created and validated automatically."
        print_info "Make sure your domain's Route53 hosted zone is properly configured."
    fi
    
    echo
    print_success "Setup completed! 🎉"
}

# Run main function
main "$@"