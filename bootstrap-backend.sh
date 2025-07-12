#!/bin/bash

# Bootstrap Terraform Backend
# Creates S3 bucket and DynamoDB table for Terraform state management

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Default values
DEFAULT_REGION="us-east-1"
DEFAULT_PROFILE="default"

# Function to prompt user input
prompt_input() {
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

# Function to check if AWS CLI is available
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed or not in PATH"
        exit 1
    fi
}

# Function to check AWS credentials
check_aws_credentials() {
    local profile="$1"
    
    if ! aws sts get-caller-identity --profile "$profile" &> /dev/null; then
        print_error "AWS credentials not configured for profile: $profile"
        print_info "Run: aws configure --profile $profile"
        exit 1
    fi
}

# Function to create S3 bucket for Terraform state
create_state_bucket() {
    local bucket_name="$1"
    local region="$2"
    local profile="$3"
    
    print_info "Creating S3 bucket: $bucket_name"
    
    # Check if bucket already exists
    if aws s3api head-bucket --bucket "$bucket_name" --profile "$profile" 2>/dev/null; then
        print_warning "S3 bucket $bucket_name already exists"
        return 0
    fi
    
    # Create bucket
    if [ "$region" = "us-east-1" ]; then
        # us-east-1 doesn't need LocationConstraint
        aws s3api create-bucket \
            --bucket "$bucket_name" \
            --profile "$profile"
    else
        aws s3api create-bucket \
            --bucket "$bucket_name" \
            --region "$region" \
            --profile "$profile" \
            --create-bucket-configuration LocationConstraint="$region"
    fi
    
    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket "$bucket_name" \
        --profile "$profile" \
        --versioning-configuration Status=Enabled
    
    # Enable server-side encryption
    aws s3api put-bucket-encryption \
        --bucket "$bucket_name" \
        --profile "$profile" \
        --server-side-encryption-configuration '{
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }
            ]
        }'
    
    # Block public access
    aws s3api put-public-access-block \
        --bucket "$bucket_name" \
        --profile "$profile" \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    
    print_success "S3 bucket created: $bucket_name"
}

# Function to create DynamoDB table for state locking
create_lock_table() {
    local table_name="$1"
    local region="$2"
    local profile="$3"
    
    print_info "Creating DynamoDB table: $table_name"
    
    # Check if table already exists
    if aws dynamodb describe-table --table-name "$table_name" --region "$region" --profile "$profile" &>/dev/null; then
        print_warning "DynamoDB table $table_name already exists"
        return 0
    fi
    
    # Create table
    aws dynamodb create-table \
        --table-name "$table_name" \
        --region "$region" \
        --profile "$profile" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --tags Key=Purpose,Value=TerraformStateLock
    
    # Wait for table to be active
    print_info "Waiting for DynamoDB table to be active..."
    aws dynamodb wait table-exists \
        --table-name "$table_name" \
        --region "$region" \
        --profile "$profile"
    
    print_success "DynamoDB table created: $table_name"
}

# Function to generate backend configuration
generate_backend_config() {
    local bucket_name="$1"
    local region="$2"
    local profile="$3"
    local key="$4"
    local lock_table="$5"
    
    cat > backend.tf << EOF
# Terraform Backend Configuration
# This file configures remote state storage in S3 with DynamoDB locking

terraform {
  backend "s3" {
    bucket         = "$bucket_name"
    key            = "$key"
    region         = "$region"
    profile        = "$profile"
    dynamodb_table = "$lock_table"
    encrypt        = true
  }
}
EOF
    
    print_success "Backend configuration created: backend.tf"
}

# Main function
main() {
    echo -e "${GREEN}"
    echo "🚀 Terraform Backend Bootstrap"
    echo "=============================="
    echo -e "${NC}"
    
    print_info "This script will create AWS resources for Terraform state management:"
    print_info "• S3 bucket for state storage"
    print_info "• DynamoDB table for state locking"
    print_info "• backend.tf configuration file"
    echo
    
    # Check prerequisites
    check_aws_cli
    
    # Get configuration
    auto_region=$(aws configure get region 2>/dev/null || echo "$DEFAULT_REGION")
    auto_profile="${AWS_PROFILE:-$DEFAULT_PROFILE}"
    
    prompt_input "AWS Region" "$auto_region" "region"
    prompt_input "AWS Profile" "$auto_profile" "profile"
    
    # Check credentials
    check_aws_credentials "$profile"
    
    # Get AWS account ID for unique naming
    aws_account_id=$(aws sts get-caller-identity --profile "$profile" --query Account --output text)
    
    # Generate default names
    default_bucket="terraform-state-$aws_account_id-$region"
    default_table="terraform-state-lock"
    default_key="terraform.tfstate"
    
    prompt_input "S3 bucket name for state" "$default_bucket" "bucket_name"
    prompt_input "DynamoDB table name for locking" "$default_table" "lock_table"
    prompt_input "State file key" "$default_key" "state_key"
    
    echo
    print_info "Configuration Summary:"
    echo "• S3 Bucket: $bucket_name"
    echo "• DynamoDB Table: $lock_table"
    echo "• Region: $region"
    echo "• Profile: $profile"
    echo "• State Key: $state_key"
    echo
    
    read -p "$(echo -e "${YELLOW}Proceed with backend creation? (y/N):${NC} ")" confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Backend creation cancelled."
        exit 0
    fi
    
    echo
    print_info "=== Creating Backend Resources ==="
    
    # Create resources
    create_state_bucket "$bucket_name" "$region" "$profile"
    create_lock_table "$lock_table" "$region" "$profile"
    generate_backend_config "$bucket_name" "$region" "$profile" "$state_key" "$lock_table"
    
    echo
    print_success "Backend bootstrap completed! 🎉"
    echo
    print_info "=== Next Steps ==="
    echo "1. Run: terraform init"
    echo "2. When prompted, type 'yes' to migrate existing state (if any)"
    echo "3. Continue with normal Terraform workflow"
    echo
    print_warning "Note: Keep the backend.tf file in your repository"
    print_warning "The S3 bucket and DynamoDB table will incur small ongoing costs"
}

# Handle command line arguments
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Bootstrap Terraform backend with S3 and DynamoDB"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_PROFILE   AWS profile to use (default: default)"
    echo ""
    exit 0
fi

# Run main function
main "$@"