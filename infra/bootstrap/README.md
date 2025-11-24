# Bootstrap Infrastructure

This directory contains Terraform configuration to set up:

1. S3 bucket for Terraform state storage
2. DynamoDB table for state locking
3. GitHub OIDC provider for GitHub Actions
4. IAM role for GitHub Actions to assume

## Usage

1. Edit `main.tf` and replace `YOUR_GITHUB_USERNAME` with your GitHub username
2. Run:
   ```bash
   terraform init
   terraform apply
   ```
3. Note the outputs for use in GitHub secrets

## Important

Run this ONCE before deploying stage or prod environments.
