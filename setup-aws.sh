#!/bin/bash
set -e  # Exit on any error

echo "🚀 CloudShop AWS Setup Script"
echo "============================="
echo ""
echo "This script will automatically deploy CloudShop to AWS:"
echo "  1. Bootstrap (Terraform state, OIDC)"
echo "  2. Stage environment (VPC, ECS, RDS, ALB, S3)"
echo "  3. Stage backend (Docker build & deploy)"
echo "  4. Stage frontend (React build & deploy)"
echo "  5. Production environment (VPC, ECS, RDS, ALB, S3)"
echo "  6. Production backend (Docker build & deploy)"
echo "  7. Production frontend (React build & deploy)"
echo ""
echo "⏱️  Estimated time: 20-30 minutes"
echo "💰 Estimated cost: ~$110/month ($55 per environment)"
echo ""
read -p "Do you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Setup cancelled."
    exit 0
fi

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"

echo ""
echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"
echo ""
echo "Starting setup..."
echo ""

# Track start time
START_TIME=$(date +%s)

# ============================================================================
# STEP 1: Bootstrap
# ============================================================================
echo "═══════════════════════════════════════════════════════════"
echo "Step 1/7: Deploying Bootstrap Infrastructure"
echo "═══════════════════════════════════════════════════════════"
echo "Creating: S3 state bucket, DynamoDB locks, GitHub OIDC"
echo ""

cd infra/bootstrap
terraform init
terraform apply -auto-approve

echo ""
echo "✅ Bootstrap complete!"
echo ""
sleep 2

# ============================================================================
# STEP 2: Stage Infrastructure
# ============================================================================
echo "═══════════════════════════════════════════════════════════"
echo "Step 2/7: Deploying Stage Infrastructure"
echo "═══════════════════════════════════════════════════════════"
echo "Creating: VPC, ECS, RDS, ALB, S3, ECR"
echo "⏱️  This will take 5-10 minutes..."
echo ""

cd ../envs/stage
terraform init
terraform apply -auto-approve -var="db_password=StagePass123"

# Get stage outputs
STAGE_ALB=$(terraform output -raw alb_dns_name)
STAGE_FRONTEND_BUCKET=$(terraform output -raw frontend_bucket_name)

echo ""
echo "✅ Stage infrastructure complete!"
echo "   ALB: $STAGE_ALB"
echo "   Frontend Bucket: $STAGE_FRONTEND_BUCKET"
echo ""
sleep 2

# ============================================================================
# STEP 3: Stage Backend
# ============================================================================
echo "═══════════════════════════════════════════════════════════"
echo "Step 3/7: Building and Deploying Stage Backend"
echo "═══════════════════════════════════════════════════════════"
echo "Building Docker image for x86_64 architecture..."
echo ""

cd ../../../backend

# Login to ECR
echo "Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin \
    $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build image
echo "Building Docker image..."
docker build --platform linux/amd64 \
    -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/stage-cloudshop-backend:latest \
    .

# Push image
echo "Pushing to ECR..."
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/stage-cloudshop-backend:latest

# Deploy to ECS
echo "Deploying to ECS..."
aws ecs update-service \
    --cluster stage-cluster \
    --service stage-backend-blue \
    --force-new-deployment \
    --region $AWS_REGION \
    --no-cli-pager

# Wait for deployment
echo "Waiting for ECS service to stabilize (2-3 minutes)..."
aws ecs wait services-stable \
    --cluster stage-cluster \
    --services stage-backend-blue \
    --region $AWS_REGION

echo ""
echo "✅ Stage backend deployed!"
echo ""
sleep 2

# ============================================================================
# STEP 4: Stage Frontend
# ============================================================================
echo "═══════════════════════════════════════════════════════════"
echo "Step 4/7: Building and Deploying Stage Frontend"
echo "═══════════════════════════════════════════════════════════"
echo ""

cd ../frontend

# Install dependencies
echo "Installing dependencies..."
npm install --silent

# Build
echo "Building React app..."
export REACT_APP_API_URL=http://$STAGE_ALB
npm run build

# Deploy to S3
echo "Deploying to S3..."
aws s3 sync build/ s3://$STAGE_FRONTEND_BUCKET/ --delete --no-progress

STAGE_FRONTEND_URL="http://$STAGE_FRONTEND_BUCKET.s3-website-$AWS_REGION.amazonaws.com"

echo ""
echo "✅ Stage frontend deployed!"
echo "   URL: $STAGE_FRONTEND_URL"
echo ""
sleep 2

# ============================================================================
# STEP 5: Production Infrastructure
# ============================================================================
echo "═══════════════════════════════════════════════════════════"
echo "Step 5/7: Deploying Production Infrastructure"
echo "═══════════════════════════════════════════════════════════"
echo "Creating: VPC, ECS, RDS, ALB, S3, ECR"
echo "⏱️  This will take 5-10 minutes..."
echo ""

cd ../infra/envs/prod
terraform init
terraform apply -auto-approve -var="db_password=ProdPass456"

# Get prod outputs
PROD_ALB=$(terraform output -raw alb_dns_name)
PROD_FRONTEND_BUCKET=$(terraform output -raw frontend_bucket_name)

echo ""
echo "✅ Production infrastructure complete!"
echo "   ALB: $PROD_ALB"
echo "   Frontend Bucket: $PROD_FRONTEND_BUCKET"
echo ""
sleep 2

# ============================================================================
# STEP 6: Production Backend
# ============================================================================
echo "═══════════════════════════════════════════════════════════"
echo "Step 6/7: Building and Deploying Production Backend"
echo "═══════════════════════════════════════════════════════════"
echo ""

cd ../../../backend

# Build image
echo "Building Docker image..."
docker build --platform linux/amd64 \
    -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/prod-cloudshop-backend:latest \
    .

# Push image
echo "Pushing to ECR..."
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/prod-cloudshop-backend:latest

# Deploy to ECS
echo "Deploying to ECS..."
aws ecs update-service \
    --cluster prod-cluster \
    --service prod-backend-blue \
    --force-new-deployment \
    --region $AWS_REGION \
    --no-cli-pager

# Wait for deployment
echo "Waiting for ECS service to stabilize (2-3 minutes)..."
aws ecs wait services-stable \
    --cluster prod-cluster \
    --services prod-backend-blue \
    --region $AWS_REGION

echo ""
echo "✅ Production backend deployed!"
echo ""
sleep 2

# ============================================================================
# STEP 7: Production Frontend
# ============================================================================
echo "═══════════════════════════════════════════════════════════"
echo "Step 7/7: Building and Deploying Production Frontend"
echo "═══════════════════════════════════════════════════════════"
echo ""

cd ../frontend

# Build
echo "Building React app..."
export REACT_APP_API_URL=http://$PROD_ALB
npm run build

# Deploy to S3
echo "Deploying to S3..."
aws s3 sync build/ s3://$PROD_FRONTEND_BUCKET/ --delete --no-progress

PROD_FRONTEND_URL="http://$PROD_FRONTEND_BUCKET.s3-website-$AWS_REGION.amazonaws.com"

echo ""
echo "✅ Production frontend deployed!"
echo "   URL: $PROD_FRONTEND_URL"
echo ""

# ============================================================================
# COMPLETION
# ============================================================================
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "🎉 CloudShop Setup Complete!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "⏱️  Total time: ${MINUTES}m ${SECONDS}s"
echo ""
echo "📍 STAGE ENVIRONMENT"
echo "   Frontend: $STAGE_FRONTEND_URL"
echo "   API:      http://$STAGE_ALB"
echo "   Health:   http://$STAGE_ALB/health"
echo "   Docs:     http://$STAGE_ALB/docs"
echo ""
echo "📍 PRODUCTION ENVIRONMENT"
echo "   Frontend: $PROD_FRONTEND_URL"
echo "   API:      http://$PROD_ALB"
echo "   Health:   http://$PROD_ALB/health"
echo "   Docs:     http://$PROD_ALB/docs"
echo ""
echo "🔑 CREDENTIALS"
echo "   AWS Account: $AWS_ACCOUNT_ID"
echo "   Region:      $AWS_REGION"
echo "   Stage DB:    StagePass123"
echo "   Prod DB:     ProdPass456"
echo ""
echo "✅ NEXT STEPS"
echo "   1. Test stage:      open $STAGE_FRONTEND_URL"
echo "   2. Test production: open $PROD_FRONTEND_URL"
echo "   3. View logs:       aws logs tail /ecs/stage/backend-blue --follow"
echo "   4. Monitor costs:   Check AWS Cost Explorer"
echo ""
echo "💰 ESTIMATED MONTHLY COST"
echo "   Stage:      ~\$55/month"
echo "   Production: ~\$55/month"
echo "   Total:      ~\$110/month"
echo ""
echo "🧹 TO CLEANUP"
echo "   Run: ./cleanup-aws.sh"
echo ""
echo "📚 DOCUMENTATION"
echo "   See: COMPLETE_GUIDE.md"
echo ""
