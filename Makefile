# Makefile for AWS Static Site Terraform

.PHONY: help setup quick-setup backend init plan apply destroy clean

# Default target
help:
	@echo "Available commands:"
	@echo "  setup       - Interactive setup with all options"
	@echo "  quick       - Quick setup with defaults"
	@echo "  backend     - Setup Terraform backend only"
	@echo "  init        - Initialize Terraform"
	@echo "  plan        - Plan Terraform changes"
	@echo "  apply       - Apply Terraform changes"
	@echo "  destroy     - Destroy all resources"
	@echo "  clean       - Clean generated files"

# Interactive setup
setup:
	@./setup.sh

# Quick setup
quick:
	@read -p "Project name: " project && \
	 read -p "Domain name: " domain && \
	 ./quick-start.sh $$project $$domain

# Backend setup only
backend:
	@./bootstrap-backend.sh

# Terraform commands
init:
	@terraform init

plan:
	@terraform plan

apply:
	@terraform apply

destroy:
	@terraform destroy

# Clean generated files
clean:
	@rm -f terraform.tfvars backend.tf
	@rm -rf .terraform/
	@rm -f .terraform.lock.hcl
	@rm -f terraform.tfstate*