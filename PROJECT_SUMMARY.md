# CloudShop Project - Complete Implementation

## ✅ What's Been Created

### 1. Backend (FastAPI)
- **Location**: `backend/`
- **Features**:
  - Products CRUD API (GET, POST, DELETE)
  - Health check endpoint
  - PostgreSQL database integration
  - Auto-initialization with sample data
- **Files**:
  - `app/main.py` - FastAPI application
  - `app/db.py` - Database connection and schema
  - `tests/test_main.py` - Basic tests
  - `Dockerfile` - Container image
  - `requirements.txt` - Python dependencies

### 2. Frontend (React)
- **Location**: `frontend/`
- **Features**:
  - Product listing display
  - API integration
  - Responsive design
- **Files**:
  - `src/index.js` - React app
  - `public/index.html` - HTML template
  - `package.json` - Node dependencies
  - `Dockerfile` - Multi-stage build

### 3. Infrastructure (Terraform)
- **Location**: `infra/`
- **Modules**:
  - `vpc/` - VPC with public subnets (cost-optimized, no NAT)
  - `alb/` - Application Load Balancer with blue/green target groups
  - `ecs/` - ECS Fargate cluster with blue/green services
  - `rds/` - PostgreSQL database (db.t3.micro)
  - `s3/` - Frontend hosting and data buckets

- **Environments**:
  - `envs/stage/` - Stage environment (us-east-1)
  - `envs/prod/` - Production environment (us-east-1)
  - `bootstrap/` - GitHub OIDC and Terraform state setup

### 4. CI/CD Workflows
- **Location**: `.github/workflows/`
- **Workflows**:
  - `pr-checks.yml` - Runs tests and validation on PRs
  - `build-and-push.yml` - Builds Docker images and pushes to ECR
  - `deploy-stage.yml` - Blue/green deployment to stage
  - `promote-prod.yml` - Blue/green deployment to prod with approval

### 5. Data Pipeline
- **Location**: `data-pipeline/`
- **Components**:
  - `lambda_preprocess/` - S3 event-triggered CSV processor
  - `scheduled_etl/` - ECS scheduled task for data aggregation

### 6. Scripts
- **Location**: `scripts/`
- `smoke-test-api.sh` - API health checks
- `smoke-test-frontend.sh` - Frontend availability checks

### 7. Local Development
- `docker-compose.yml` - Full local stack (Postgres, Backend, Frontend)

## 🎯 Blue/Green Deployment Flow

### Stage Deployment (Automatic on push to main)
1. Code pushed to `main` branch
2. `build-and-push.yml` builds backend image with git SHA tag
3. `deploy-stage.yml` workflow:
   - Reads current active color from SSM (blue or green)
   - Deploys new image to INACTIVE color
   - Waits for ECS service to be stable
   - Runs smoke tests against inactive service
   - If tests pass: switches ALB to point to new color
   - Updates SSM parameter with new active color
   - Old color remains running for quick rollback

### Production Deployment (Manual with approval)
1. Trigger `promote-prod.yml` workflow manually
2. Specify image tag from stage (git SHA)
3. GitHub requires manual approval (production environment)
4. Same blue/green process as stage
5. Zero-downtime deployment

## 📋 Setup Checklist

### Step 1: Bootstrap (One-time)
```bash
cd infra/bootstrap
# Edit main.tf - replace YOUR_GITHUB_USERNAME
terraform init
terraform apply
```

### Step 2: GitHub Configuration
Add secrets in GitHub repo settings:
- `AWS_ACCOUNT_ID` - Your AWS account ID
- `STAGE_DB_PASSWORD` - Strong password
- `PROD_DB_PASSWORD` - Strong password

Create GitHub environment:
- Name: `production`
- Add yourself as required reviewer

### Step 3: Deploy Stage
```bash
cd infra/envs/stage
terraform init
terraform apply -var="db_password=YOUR_PASSWORD"
```

### Step 4: Build Initial Image
```bash
cd backend
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
docker build -t ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/stage-cloudshop-backend:latest .
docker push ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/stage-cloudshop-backend:latest
```

### Step 5: Update ECS
```bash
cd infra/envs/stage
terraform apply -var="backend_image_tag=latest" -var="db_password=YOUR_PASSWORD"
```

### Step 6: Test
```bash
# Get ALB DNS
terraform output alb_dns_name

# Test API
curl http://YOUR_ALB_DNS/health
curl http://YOUR_ALB_DNS/products
```

### Step 7: Deploy Frontend
```bash
cd frontend
npm install
npm run build
BUCKET=$(terraform -chdir=../infra/envs/stage output -raw frontend_bucket)
aws s3 sync build/ s3://$BUCKET/
```

### Step 8: CI/CD Ready
Now push to `main` and workflows will handle deployments automatically!

## 💰 Cost Optimization

This project is optimized for learning:
- ✅ Public subnets only (saves ~$32/month per NAT Gateway)
- ✅ Minimal instance sizes (db.t3.micro, 256 CPU/512 MB ECS)
- ✅ Single region for both environments
- ✅ Pay-per-request DynamoDB for locks
- ✅ S3 for frontend (pennies per month)

**Estimated monthly cost**: $50-70 for both environments running 24/7

**To reduce further**:
- Stop RDS when not in use
- Set ECS desired count to 0
- Use `terraform destroy` when done

## 🧪 Testing Scenarios

### Test Blue/Green Deployment
1. Make a change to backend (e.g., add new endpoint)
2. Push to `main`
3. Watch GitHub Actions deploy to inactive color
4. See traffic switch after smoke tests pass
5. Old version still running for rollback

### Test Rollback
1. Deploy a broken version
2. Smoke tests fail
3. Deployment stops, traffic stays on old version
4. Fix code and redeploy

### Test Production Promotion
1. Deploy to stage successfully
2. Trigger `promote-prod` with stage image tag
3. Approve in GitHub UI
4. Watch blue/green deployment in prod

## 📁 Project Structure Summary

```
cloudshop/
├── backend/              # FastAPI service
├── frontend/             # React app
├── data-pipeline/        # Lambda + ETL
├── infra/
│   ├── bootstrap/        # One-time setup
│   ├── modules/          # Reusable Terraform
│   └── envs/            # Stage + Prod
├── .github/workflows/    # CI/CD pipelines
├── scripts/             # Helper scripts
├── docker-compose.yml   # Local development
├── README.md            # Project overview
├── SETUP.md             # Detailed setup guide
└── PROJECT_SUMMARY.md   # This file
```

## 🚀 Next Steps

1. Follow SETUP.md for detailed deployment instructions
2. Customize the application for your learning goals
3. Practice breaking things and fixing them
4. Experiment with different deployment strategies
5. Add monitoring and alerting (CloudWatch)
6. Implement database migrations (Alembic)
7. Add more comprehensive tests
8. Set up CloudFront for frontend

## 📚 Learning Outcomes

By completing this project, you'll learn:
- ✅ Blue/green deployment patterns
- ✅ ECS Fargate with ALB
- ✅ Terraform infrastructure as code
- ✅ GitHub Actions CI/CD
- ✅ AWS networking (VPC, subnets, security groups)
- ✅ RDS database management
- ✅ S3 static hosting
- ✅ IAM roles and OIDC
- ✅ Container orchestration
- ✅ Zero-downtime deployments

## 🆘 Troubleshooting

See SETUP.md for detailed troubleshooting guide.

Common issues:
- ECS tasks not starting → Check CloudWatch logs
- Database connection errors → Verify security groups
- GitHub Actions failing → Check secrets and IAM role
- Terraform errors → Ensure bootstrap completed first

## 🧹 Cleanup

```bash
# Destroy stage
cd infra/envs/stage && terraform destroy

# Destroy prod
cd infra/envs/prod && terraform destroy

# Destroy bootstrap (last)
cd infra/bootstrap && terraform destroy
```

---

**Ready to deploy!** Start with SETUP.md for step-by-step instructions.
