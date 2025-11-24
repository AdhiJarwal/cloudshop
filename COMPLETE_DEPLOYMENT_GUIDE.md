# CloudShop - Complete Deployment Guide

## 📋 Prerequisites

- AWS Account with CLI configured (`aws configure`)
- GitHub account
- Docker Desktop installed
- Terraform >= 1.0
- Node.js >= 18
- Python >= 3.11

## 🚀 Step-by-Step Deployment

### **Step 1: Test Local Environment (5 minutes)**

```bash
cd /Users/adhiraj.jarwal/Desktop/cloudshop

# Start local stack
docker-compose up -d

# Wait 30 seconds
sleep 30

# Test backend
curl http://localhost:8000/health
curl http://localhost:8000/products

# Test frontend
open http://localhost:3000

# Stop when done
docker-compose down
```

### **Step 2: Create GitHub Repository (2 minutes)**

1. Go to GitHub.com
2. Create new repository: `cloudshop`
3. Make it **public**

### **Step 3: Update Configuration (2 minutes)**

Edit `infra/bootstrap/main.tf`:
- Line 18: Change bucket name to `YOUR_USERNAME-cloudshop-terraform-state`
- Line 86: Change to `repo:YOUR_GITHUB_USERNAME/cloudshop:*`

### **Step 4: Push to GitHub (2 minutes)**

```bash
cd /Users/adhiraj.jarwal/Desktop/cloudshop

git init
git add .
git commit -m "Initial commit: CloudShop with blue/green deployment"
git remote add origin https://github.com/YOUR_USERNAME/cloudshop.git
git branch -M main
git push -u origin main
```

### **Step 5: Bootstrap AWS (10 minutes)**

```bash
cd infra/bootstrap
terraform init
terraform apply --auto-approve

# Note the outputs
terraform output
```

### **Step 6: Configure GitHub Secrets (3 minutes)**

Go to: `https://github.com/YOUR_USERNAME/cloudshop/settings/secrets/actions`

Add these secrets:
- `AWS_ACCOUNT_ID`: Your 12-digit AWS account ID
- `STAGE_DB_PASSWORD`: `StagePass123`
- `PROD_DB_PASSWORD`: `ProdPass456`

### **Step 7: Create GitHub Environment (2 minutes)**

Go to: `https://github.com/YOUR_USERNAME/cloudshop/settings/environments`

1. Click "New environment"
2. Name: `production`
3. Add protection rule: "Required reviewers"
4. Add yourself as reviewer
5. Save

### **Step 8: Deploy Stage Infrastructure (15 minutes)**

```bash
cd infra/envs/stage
terraform init
terraform apply -var="db_password=StagePass123" --auto-approve

# Note the outputs
terraform output
```

### **Step 9: Build and Push Backend Image (5 minutes)**

```bash
cd backend

# Login to ECR
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# Build for x86_64 (important!)
docker build --platform linux/amd64 \
  -t $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/stage-cloudshop-backend:latest .

# Push
docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/stage-cloudshop-backend:latest
```

### **Step 10: Update ECS Service (3 minutes)**

```bash
# Force new deployment with the image
aws ecs update-service \
  --cluster stage-cluster \
  --service stage-backend-blue \
  --force-new-deployment \
  --region us-east-1

# Wait for service to stabilize (2-3 minutes)
aws ecs wait services-stable \
  --cluster stage-cluster \
  --services stage-backend-blue \
  --region us-east-1
```

### **Step 11: Test Stage Backend (1 minute)**

```bash
cd infra/envs/stage
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test API
curl http://$ALB_DNS/health
curl http://$ALB_DNS/products

# Should see 3 sample products
```

### **Step 12: Deploy Frontend (5 minutes)**

```bash
cd frontend

# Install dependencies
npm install

# Build with API URL
REACT_APP_API_URL=http://$ALB_DNS npm run build

# Upload to S3
BUCKET=$(terraform -chdir=../infra/envs/stage output -raw frontend_bucket)
aws s3 sync build/ s3://$BUCKET/

# Get frontend URL
echo "Frontend: http://$BUCKET.s3-website-us-east-1.amazonaws.com"
```

### **Step 13: Test Full Stack (1 minute)**

Open the frontend URL in browser and test:
- View products
- Add new product
- Delete product

### **Step 14: Deploy Production (Optional, 20 minutes)**

```bash
cd infra/envs/prod
terraform init
terraform apply -var="db_password=ProdPass456" --auto-approve

# Build and push prod image
cd ../../backend
docker build --platform linux/amd64 \
  -t $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/prod-cloudshop-backend:latest .
docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/prod-cloudshop-backend:latest

# Update ECS
aws ecs update-service \
  --cluster prod-cluster \
  --service prod-backend-blue \
  --force-new-deployment \
  --region us-east-1
```

### **Step 15: Test CI/CD Pipeline (10 minutes)**

```bash
# Make a small change
echo "# Test CI/CD" >> README.md

# Commit and push
git add .
git commit -m "Test CI/CD pipeline"
git push

# Watch GitHub Actions
# Go to: https://github.com/YOUR_USERNAME/cloudshop/actions
```

## ✅ Success Indicators

After completion:
- ✅ Local: `docker-compose up` works
- ✅ Stage API: Returns healthy status
- ✅ Stage Frontend: Accessible and functional
- ✅ CI/CD: GitHub Actions run successfully
- ✅ Production: (Optional) Deployed and working

## 🌐 Access Points

### Stage Environment
- **API**: `http://stage-alb-XXXXXXXXX.us-east-1.elb.amazonaws.com`
- **Frontend**: `http://stage-cloudshop-frontend-ACCOUNT_ID.s3-website-us-east-1.amazonaws.com`
- **API Docs**: `http://stage-alb-XXXXXXXXX.us-east-1.elb.amazonaws.com/docs`

### Production Environment
- **API**: `http://prod-alb-XXXXXXXXX.us-east-1.elb.amazonaws.com`
- **Frontend**: `http://prod-cloudshop-frontend-ACCOUNT_ID.s3-website-us-east-1.amazonaws.com`

## 💰 Cost Management

### Monthly Costs (24/7 operation)
- **Stage**: ~$55/month
- **Production**: ~$55/month
- **Total**: ~$110/month for both environments

### Cost Breakdown
- RDS db.t3.micro: ~$15/month
- ECS Fargate (1 task): ~$15/month
- ALB: ~$20/month
- S3, CloudWatch, etc.: ~$5/month

### Save Money
```bash
# Stop RDS when not using
aws rds stop-db-instance --db-instance-identifier stage-cloudshop-db

# Set ECS desired count to 0
aws ecs update-service --cluster stage-cluster --service stage-backend-blue --desired-count 0
```

## 🧹 Complete Cleanup

### Option 1: Use Cleanup Script (Recommended)
```bash
cd /Users/adhiraj.jarwal/Desktop/cloudshop
./cleanup-aws.sh
```

### Option 2: Manual Cleanup
```bash
# 1. Empty S3 buckets
aws s3 rm s3://stage-cloudshop-frontend-ACCOUNT_ID --recursive
aws s3 rm s3://stage-cloudshop-data-ACCOUNT_ID --recursive

# 2. Delete ECR images
aws ecr batch-delete-image \
  --repository-name stage-cloudshop-backend \
  --image-ids "$(aws ecr list-images --repository-name stage-cloudshop-backend --query 'imageIds[*]' --output json)" \
  --region us-east-1

# 3. Destroy environments
cd infra/envs/stage
terraform destroy -var="db_password=StagePass123"

cd ../prod
terraform destroy -var="db_password=ProdPass456"

cd ../../bootstrap
terraform destroy
```

## 🔧 Troubleshooting

### Issue: ECS tasks failing with "exec format error"
**Solution**: Rebuild Docker image with `--platform linux/amd64` flag

### Issue: Frontend shows "Failed to fetch"
**Solution**: CORS is now fixed in backend. Rebuild and redeploy backend image.

### Issue: Green service creation fails
**Solution**: Green service is commented out. It's created only during blue/green deployments.

### Issue: Database connection errors
**Solution**: Check security groups allow ECS → RDS traffic on port 5432

### Issue: GitHub Actions failing
**Solution**: Verify all secrets are set correctly and IAM role ARN is correct

## 📊 Architecture Overview

```
┌─────────────┐
│   GitHub    │
│   Actions   │
└──────┬──────┘
       │ (OIDC)
       ▼
┌─────────────┐     ┌──────────────┐
│     ECR     │────▶│  ECS Fargate │
│   (Images)  │     │  (Blue/Green)│
└─────────────┘     └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │     ALB      │
                    │ (Target Grps)│
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │   Internet   │
                    └──────────────┘

┌─────────────┐     ┌──────────────┐
│     RDS     │◀────│  ECS Tasks   │
│ (PostgreSQL)│     │   (Backend)  │
└─────────────┘     └──────────────┘

┌─────────────┐
│  S3 Bucket  │
│  (Frontend) │
└─────────────┘
```

## 🎓 What You've Built

- ✅ Production-ready AWS infrastructure
- ✅ Blue/green deployment system
- ✅ Automated CI/CD pipeline
- ✅ Infrastructure as Code with Terraform
- ✅ Containerized microservices
- ✅ Zero-downtime deployments
- ✅ Cost-optimized architecture

## 📚 Next Steps

1. Add CloudFront for frontend CDN
2. Implement database migrations (Alembic)
3. Add monitoring dashboards (CloudWatch)
4. Set up alerts and notifications
5. Implement automated testing
6. Add API authentication (JWT)
7. Set up custom domain with Route53

---

**Total Deployment Time**: ~60 minutes
**Skill Level**: Intermediate
**AWS Services Used**: 10+ services
