# AWS Static Site Infrastructure

A generic Terraform configuration for deploying static websites on AWS using S3, CloudFront, and Route53.

## 🏢 Architecture

This configuration creates a complete static website hosting infrastructure on AWS:
- **S3 Bucket**: Stores your static website files
- **CloudFront**: Global CDN for fast content delivery
- **Route53**: DNS management for custom domains
- **SSL/TLS**: Automatic HTTPS with AWS Certificate Manager

## 📁 Project Structure

```
aws-static-site-terraform/
├── main.tf                   # Provider and backend configuration
├── variables.tf              # Input variables
├── static-site.tf            # S3 and CloudFront resources
├── acm.tf                   # SSL certificate management
├── route53.tf               # DNS records
├── outputs.tf               # Output values
├── setup.sh                 # Interactive setup script
├── quick-start.sh           # Quick setup with defaults
├── bootstrap-backend.sh     # Backend setup script
├── deploy-sample.sh         # Complete demo deployment script
├── terraform.tfvars.example # Configuration template
├── backend.tf.example       # Backend configuration template
├── sample-website/          # Sample website files
│   ├── index.html           # Homepage
│   ├── about.html           # About page
│   └── contact.html         # Contact page
├── Makefile                 # Convenient commands
└── README.md                # This file
```

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- A registered domain name with Route53 hosted zone
- (Optional) SSL certificate issued by AWS Certificate Manager (auto-created by default)

### Setup

#### Option 1: Quick Start (Fastest)

```bash
# One-command setup with defaults (includes backend setup)
./quick-start.sh my-project example.com

# Then deploy
terraform init && terraform plan && terraform apply
```

This will:
- Auto-detect AWS credentials and region
- Create terraform.tfvars with sensible defaults
- Optionally create S3 bucket and DynamoDB table for state management
- Generate backend.tf configuration

#### Option 2: Interactive Setup (Recommended)

1. **Configure AWS credentials**
   ```bash
   aws configure --profile your-profile
   export AWS_PROFILE=your-profile
   aws sts get-caller-identity  # Verify credentials
   ```

2. **Run the interactive setup script**
   ```bash
   ./setup.sh
   ```
   
   The script will:
   - Auto-detect your AWS account ID, region, and profile
   - List your Route53 hosted zones
   - Guide you through all configuration options
   - Optionally setup Terraform backend (S3 + DynamoDB)
   - Generate `terraform.tfvars` and `backend.tf` automatically

3. **Initialize and deploy**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

#### Option 3: Manual Setup

1. **Configure AWS credentials** (same as above)

2. **Create configuration file manually**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your actual values
   ```

3. **Initialize and deploy** (same as above)

#### Option 4: Backend Setup Only

If you only want to setup the Terraform backend:

```bash
./bootstrap-backend.sh
```

This creates:
- S3 bucket for Terraform state storage
- DynamoDB table for state locking
- backend.tf configuration file

4. **Upload your website**
   ```bash
   # Get the S3 bucket name from output
   terraform output s3_bucket_name
   
   # Upload your static files
   aws s3 sync ./your-website-files/ s3://$(terraform output -raw s3_bucket_name)/
   
   # Invalidate CloudFront cache
   aws cloudfront create-invalidation --distribution-id $(terraform output -raw cloudfront_distribution_id) --paths "/*"
   ```

### Script Features

**setup.sh** (Interactive Setup):
- Auto-detection of AWS credentials and settings
- Route53 hosted zone listing
- Input validation and smart defaults
- Backend setup integration
- Colorized output and error handling

**quick-start.sh** (Minimal Setup):
- Two-parameter setup (project name + domain)
- Automatic backend creation
- Sensible defaults for rapid deployment

**bootstrap-backend.sh** (Backend Only):
- Creates S3 bucket with encryption and versioning
- Creates DynamoDB table for state locking
- Generates backend.tf configuration
- Handles existing resources gracefully

## 🔧 Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|----------|
| `aws_account_id` | AWS Account ID | `123456789012` |
| `project_name` | Project name (lowercase, alphanumeric with hyphens) | `my-website` |
| `domain_name` | Your registered domain | `example.com` |

### Key Configuration Options

- **Domain Setup**: Choose between subdomain (`app.example.com`) or apex domain (`example.com`)
- **SSL Certificate**: Auto-create ACM certificate with DNS validation, or use existing one
- **SPA Support**: Enable Single Page Application routing
- **Caching**: Configure CloudFront TTL settings
- **Security**: SSL/TLS versions, geo-restrictions
- **Storage**: S3 versioning and encryption options

## 🔐 Security Features

- **HTTPS Only**: Automatic redirect from HTTP to HTTPS
- **Origin Access Control**: S3 bucket accessible only through CloudFront
- **S3 Security**: Public access blocked, server-side encryption enabled
- **SSL/TLS**: Modern TLS versions with SNI support
- **Access Control**: Optional geo-restrictions
- **Versioning**: Optional S3 object versioning for rollback capability
- **State Security**: Terraform state stored in encrypted S3 bucket with versioning
- **State Locking**: DynamoDB table prevents concurrent modifications

## 🛠️ Development

### Terraform Commands

```bash
# Format code
terraform fmt

# Validate configuration
terraform validate

# Plan changes
terraform plan

# Apply changes
terraform apply

# Destroy infrastructure
terraform destroy
```

### Customization

This configuration is designed to be easily customizable:

1. **Fork or clone** this repository
2. **Modify variables** in `terraform.tfvars`
3. **Extend functionality** by adding resources to `static-site.tf`
4. **Add modules** for complex setups

## ❗ Troubleshooting

### Common Issues

1. **Certificate validation timeout**: Ensure your Route53 hosted zone is properly configured and DNS propagation is complete
2. **Domain validation**: Verify your Route53 hosted zone matches your domain name exactly
3. **Permission denied**: Check AWS credentials and IAM policies (ACM, Route53, CloudFront, S3, DynamoDB permissions needed)
4. **Resource conflicts**: Ensure resource names are unique across your AWS account
5. **Certificate region**: ACM certificates for CloudFront must be created in `us-east-1` region (handled automatically)
6. **Backend migration**: When running `terraform init` with a new backend, answer 'yes' to migrate existing state
7. **State bucket exists**: If the state bucket already exists, ensure you have access and it's in the correct region

### Useful Commands

```bash
# Re-run interactive setup
./setup.sh

# Setup backend only
./bootstrap-backend.sh

# Quick start with defaults
./quick-start.sh project-name domain.com

# Check certificate status
aws acm list-certificates --region us-east-1

# Verify domain in Route53
aws route53 list-hosted-zones

# Test website deployment
curl -I https://your-domain.com

# View current configuration
cat terraform.tfvars
cat backend.tf
```

## 📝 License

This project is open source and available under the [MIT License](LICENSE).

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

## 🎯 Live Demo

### Deploy Sample Site

Want to see it in action? Deploy the included sample website:

```bash
# Deploy sample site to sample.example.com
./deploy-sample.sh
```

This will:
1. ✅ Create terraform.tfvars with sample configuration
2. ✅ Setup Terraform backend (S3 + DynamoDB)
3. ✅ Deploy infrastructure (S3, CloudFront, ACM, Route53)
4. ✅ Upload sample website files
5. ✅ Invalidate CloudFront cache
6. 🌐 **Result**: Live site at https://sample.example.com

### Sample Website Features

The included sample website demonstrates:
- 📱 **Responsive Design**: Works on all devices
- ⚡ **Fast Loading**: Optimized with modern CSS
- 🎨 **Modern UI**: Glassmorphism design with gradients
- 🔗 **Multi-page**: Index, About, Contact pages
- 📊 **Analytics Ready**: Console logging and deployment info

### Clean Up

```bash
# Remove all created resources
terraform destroy

# Clean local files
make clean
```

### Demo Configuration

- **Domain**: sample.example.com
- **AWS Account**: [Auto-detected]
- **Profile**: [Auto-detected from environment]
- **Region**: us-east-1
- **Certificate**: Auto-created with DNS validation
- **Backend**: S3 bucket with DynamoDB locking

### Expected Results

After successful deployment:

```
🎉 Deployment Complete!
✨ Your sample website is now live!

📍 Site URL: https://sample.example.com
🪣 S3 Bucket: sample-site-demo-static-site
🌐 CloudFront Distribution: E1234567890ABC
📊 Certificate: arn:aws:acm:us-east-1:123456789012:certificate/...
```