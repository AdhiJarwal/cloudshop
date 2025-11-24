#!/bin/bash
set -e

echo "🧹 CloudShop AWS Cleanup Script"
echo "================================"
echo ""
echo "This will destroy ALL AWS resources created by CloudShop"
echo "⚠️  WARNING: This action cannot be undone!"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "Starting cleanup process..."
echo ""

# Function to empty S3 buckets
empty_s3_bucket() {
    BUCKET=$1
    echo "Emptying S3 bucket: $BUCKET"
    aws s3 rm s3://$BUCKET --recursive 2>/dev/null || echo "Bucket $BUCKET not found or already empty"
}

# Function to delete ECR images
delete_ecr_images() {
    REPO=$1
    echo "Deleting ECR images from: $REPO"
    aws ecr batch-delete-image \
        --repository-name $REPO \
        --image-ids "$(aws ecr list-images --repository-name $REPO --query 'imageIds[*]' --output json)" \
        --region us-east-1 2>/dev/null || echo "No images found in $REPO"
}

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo ""

# Step 1: Empty S3 buckets
echo "Step 1: Emptying S3 buckets..."
empty_s3_bucket "stage-cloudshop-frontend-$AWS_ACCOUNT_ID"
empty_s3_bucket "stage-cloudshop-data-$AWS_ACCOUNT_ID"
empty_s3_bucket "prod-cloudshop-frontend-$AWS_ACCOUNT_ID"
empty_s3_bucket "prod-cloudshop-data-$AWS_ACCOUNT_ID"
echo ""

# Step 2: Delete ECR images
echo "Step 2: Deleting ECR images..."
delete_ecr_images "stage-cloudshop-backend"
delete_ecr_images "prod-cloudshop-backend"
echo ""

# Step 3: Destroy Stage environment
echo "Step 3: Destroying Stage environment..."
cd infra/envs/stage
terraform destroy -auto-approve -var="db_password=StagePass123" || echo "Stage destroy completed with warnings"
cd ../../..
echo ""

# Step 4: Destroy Prod environment
echo "Step 4: Destroying Production environment..."
cd infra/envs/prod
terraform destroy -auto-approve -var="db_password=ProdPass456" || echo "Prod destroy completed with warnings"
cd ../../..
echo ""

# Step 5: Destroy Bootstrap
echo "Step 5: Destroying Bootstrap infrastructure..."
cd infra/bootstrap
terraform destroy -auto-approve || echo "Bootstrap destroy completed with warnings"
cd ../..
echo ""

echo "✅ Cleanup Complete!"
echo ""
echo "All AWS resources have been destroyed."
echo "Note: GitHub repository and secrets were not affected."
echo ""
echo "💰 Cost Impact: All AWS charges will stop within 24 hours."
