# CloudShop Deployment Checklist

## ✅ Project Status: READY TO DEPLOY

All files have been created successfully. Follow this checklist to deploy.

## 📦 What's Been Created

### Backend (FastAPI)
- ✅ `backend/app/main.py` - API with products CRUD
- ✅ `backend/app/db.py` - Database connection
- ✅ `backend/app/__init__.py` - Package init
- ✅ `backend/tests/test_main.py` - Basic tests
- ✅ `backend/Dockerfile` - Container image
- ✅ `backend/requirements.txt` - Dependencies

### Frontend (React)
- ✅ `frontend/src/index.js` - React app
- ✅ `frontend/public/index.html` - HTML template
- ✅ `frontend/package.json` - Dependencies
- ✅ `frontend/Dockerfile` - Container image

### Infrastructure (Terraform)
All 24 Terraform files created:

**Modules:**
- ✅ VPC (main.tf, variables.tf, outputs.tf)
- ✅ ALB (main.tf, variables.tf, outputs.tf)
- ✅ ECS (main.tf, variables.tf, outputs.tf)
- ✅ RDS (main.tf, variables.tf, outputs.tf)
- ✅ S3 (main.tf, variables.tf, outputs.tf)

**Environments:**
- ✅ Stage (main.tf, variables.tf, outputs.tf, backend.tf)
- ✅ Prod (main.tf, variables.tf, outputs.tf, backend.tf)
- ✅ Bootstrap (main.tf)

### CI/CD Workflows
- ✅ `.github/workflows/pr-checks.yml`
- ✅ `.github/workflows/build-and-push.yml`
- ✅ `.github/workflows/deploy-stage.yml`
- ✅ `.github/workflows/promote-prod.yml`

### Data Pipeline
- ✅ `data-pipeline/lambda_preprocess/handler.py`
- ✅ `data-pipeline/scheduled_etl/job.py`
- ✅ Dockerfiles for both

### Scripts & Config
- ✅ `scripts/smoke-test-api.sh`
- ✅ `scripts/smoke-test-frontend.sh`
- ✅ `docker-compose.yml`
- ✅ `.gitignore`

### Documentation
- ✅ `README.md` - Project overview
- ✅ `SETUP.md` - Detailed setup guide
- ✅ `PROJECT_SUMMARY.md` - Complete summary
- ✅ `DEPLOYMENT_CHECKLIST.md` - This file

## 🚀 Deployment Steps

### Step 1: Test Locally (5 minutes)

```bash
cd /Users/adhiraj.jarwal/Desktop/cloudshop

# Start local stack
docker-compose up -d

# Wait 30 seconds for services to start
sleep 30

# Test backend
curl http://localhost:8000/health
curl http://localhost:8000/products

# Open frontend in browser
open http://localhost:3000

# Stop when done
docker-compose down
```

### Step 2: Push to GitHub (2 minutes)

```bash
cd /Users/adhiraj.jarwal/Desktop/cloudshop

# Initialize git if not already done
git init
git add .
git commit -m "Initial commit: CloudShop with blue/green deployment"

# Create GitHub repo and push
# Replace YOUR_USERNAME with your GitHub username
git remote add origin https://github.com/YOUR_USERNAME/cloudshop.git
git branch -M main
git push -u origin main
```

### Step 3: Bootstrap AWS (10 minutes)

```bash
cd infra/bootstrap

# IMPORTANT: Edit main.tf first
# Replace YOUR_GITHUB_USERNAME with your actual GitHub username
# Line 73: "repo:YOUR_GITHUB_USERNAME/cloudshop:*"

# Then run:
terraform init
terraform apply

# Note the outputs:
# - github_role_arn
# - terraform_state_bucket
# - terraform_locks_table
```

### Step 4: Configure GitHub Secrets (2 minutes)

Go to: `https://github.com/YOUR_USERNAME/cloudshop/settings/secrets/actions`

Add these secrets:
- `AWS_ACCOUNT_ID` = Your 12-digit AWS account ID
- `STAGE_DB_PASSWORD` = Strong password (e.g., `StagePass123!@#`)
- `PROD_DB_PASSWORD` = Different strong password (e.g., `ProdPass456!@#`)

### Step 5: Create GitHub Environment (2 minutes)

Go to: `https://github.com/YOUR_USERNAME/cloudshop/settings/environments`

1. Click "New environment"
2. Name: `production`
3. Add protection rule: "Required reviewers"
4. Add yourself as reviewer
5. Save

### Step 6: Deploy Stage Infrastructure (15 minutes)

```bash
cd infra/envs/stage

# Initialize Terraform
terraform init

# Review the plan
terraform plan -var="db_password=YOUR_STAGE_PASSWORD"

# Apply (creates VPC, ECS, RDS, ALB, S3, etc.)
terraform apply -var="db_password=YOUR_STAGE_PASSWORD"

# Note the outputs:
# - alb_dns_name (your API endpoint)
# - ecr_repository_url (for Docker push)
# - frontend_bucket (for frontend deployment)
```

### Step 7: Build and Push Initial Backend Image (5 minutes)

```bash
cd /Users/adhiraj.jarwal/Desktop/cloudshop/backend

# Get your AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# Build and push
docker build -t $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/stage-cloudshop-backend:latest .
docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/stage-cloudshop-backend:latest
```

### Step 8: Update ECS to Use Image (5 minutes)

```bash
cd infra/envs/stage

# Apply with image tag
terraform apply \
  -var="backend_image_tag=latest" \
  -var="db_password=YOUR_STAGE_PASSWORD"

# Wait for ECS service to stabilize (2-3 minutes)
aws ecs wait services-stable \
  --cluster stage-cluster \
  --services stage-backend-blue \
  --region us-east-1
```

### Step 9: Test Stage Deployment (2 minutes)

```bash
# Get ALB DNS
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test API
curl http://$ALB_DNS/health
curl http://$ALB_DNS/products

# Should see 3 sample products
```

### Step 10: Deploy Frontend to S3 (5 minutes)

```bash
cd /Users/adhiraj.jarwal/Desktop/cloudshop/frontend

# Install dependencies
npm install

# Build
REACT_APP_API_URL=http://YOUR_ALB_DNS npm run build

# Get bucket name
BUCKET=$(terraform -chdir=../infra/envs/stage output -raw frontend_bucket)

# Upload to S3
aws s3 sync build/ s3://$BUCKET/

# Get frontend URL
echo "Frontend URL: http://$BUCKET.s3-website-us-east-1.amazonaws.com"
```

### Step 11: Test CI/CD (10 minutes)

```bash
# Make a small change to backend
cd /Users/adhiraj.jarwal/Desktop/cloudshop
echo "# Test change" >> backend/app/main.py

# Commit and push
git add .
git commit -m "Test CI/CD pipeline"
git push

# Watch GitHub Actions:
# https://github.com/YOUR_USERNAME/cloudshop/actions

# Workflows will run:
# 1. build-and-push.yml - Builds Docker image
# 2. deploy-stage.yml - Deploys with blue/green
```

### Step 12: Deploy Production (Optional, 20 minutes)

```bash
cd infra/envs/prod

terraform init
terraform apply -var="db_password=YOUR_PROD_PASSWORD"

# Then use GitHub Actions to promote:
# Go to Actions → Promote to Production
# Click "Run workflow"
# Enter image tag (git SHA from stage)
# Approve when prompted
```

## 🎯 Success Criteria

After deployment, you should have:

- ✅ Stage environment running in AWS
- ✅ Backend API accessible via ALB
- ✅ Frontend accessible via S3 website
- ✅ Database with sample products
- ✅ CI/CD pipeline working
- ✅ Blue/green deployment functional

## 🧪 Testing Blue/Green Deployment

1. Make a change to backend code
2. Push to `main` branch
3. Watch GitHub Actions deploy to inactive color
4. See smoke tests run
5. Watch traffic switch to new version
6. Old version stays running for rollback

## 💰 Cost Estimate

Running 24/7:
- RDS db.t3.micro: ~$15/month
- ECS Fargate (2 tasks): ~$15/month
- ALB: ~$20/month
- S3, CloudWatch, etc.: ~$5/month

**Total: ~$55/month per environment**

To save costs:
- Stop RDS when not in use
- Set ECS desired count to 0
- Use `terraform destroy` when done learning

## 🧹 Cleanup

When you're done:

```bash
# Destroy stage
cd infra/envs/stage
terraform destroy -var="db_password=YOUR_STAGE_PASSWORD"

# Destroy prod (if created)
cd infra/envs/prod
terraform destroy -var="db_password=YOUR_PROD_PASSWORD"

# Destroy bootstrap (last)
cd infra/bootstrap
terraform destroy
```

## 🆘 Troubleshooting

### ECS tasks not starting
```bash
# Check logs
aws logs tail /ecs/stage/backend-blue --follow
```

### Database connection errors
- Verify security groups allow ECS → RDS traffic
- Check RDS is publicly accessible
- Verify DB credentials

### GitHub Actions failing
- Check secrets are set correctly
- Verify IAM role ARN in bootstrap/main.tf
- Ensure GitHub username is correct in OIDC trust policy

### Terraform errors
- Ensure bootstrap completed successfully
- Check S3 bucket and DynamoDB table exist
- Verify AWS credentials are configured

## 📚 Next Steps

1. Add monitoring (CloudWatch dashboards)
2. Implement database migrations (Alembic)
3. Add more comprehensive tests
4. Set up CloudFront for frontend
5. Implement Lambda data pipeline
6. Add scheduled ETL job
7. Practice breaking and fixing things!

## 🎓 Learning Outcomes

By completing this project, you've learned:
- ✅ Blue/green deployment patterns
- ✅ ECS Fargate orchestration
- ✅ Terraform infrastructure as code
- ✅ GitHub Actions CI/CD
- ✅ AWS networking and security
- ✅ Zero-downtime deployments
- ✅ Real-world DevOps practices

---

**Ready to deploy!** Start with Step 1 and work through each step.

For detailed explanations, see `SETUP.md`.
For project overview, see `README.md` and `PROJECT_SUMMARY.md`.
