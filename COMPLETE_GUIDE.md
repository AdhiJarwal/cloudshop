# CloudShop - Complete Guide

**A complete e-commerce application with AWS blue/green deployment using ECS Fargate, Terraform, and GitHub Actions.**

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Project Overview](#project-overview)
3. [Architecture](#architecture)
4. [Initial Setup](#initial-setup)
5. [Local Development](#local-development)
6. [AWS Deployment](#aws-deployment)
7. [GitHub Actions CI/CD](#github-actions-cicd)
8. [Testing](#testing)
9. [Monitoring](#monitoring)
10. [Troubleshooting](#troubleshooting)
11. [Cleanup](#cleanup)

---

## Prerequisites

### Required Tools
- **AWS Account** (Account ID: 746669238399)
- **AWS CLI** (configured with credentials)
- **Docker** (for building images)
- **Terraform** (v1.6.0+)
- **Node.js** (v18+)
- **Python** (v3.11+)
- **Git** (for version control)

### AWS Credentials Setup
```bash
# Configure AWS CLI
aws configure
# Enter:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region: us-east-1
# - Default output format: json

# Verify
aws sts get-caller-identity
```

### GitHub Repository
- Repository: https://github.com/AdhiJarwal/cloudshop
- Clone: `git clone https://github.com/AdhiJarwal/cloudshop.git`

---

## Project Overview

### What This Project Does
CloudShop is an e-commerce application that demonstrates:
- Zero-downtime deployments on AWS
- Infrastructure as Code with Terraform
- Automated CI/CD with GitHub Actions
- Separate stage and production environments

### Technology Stack
- **Backend**: FastAPI (Python) with PostgreSQL
- **Frontend**: React (JavaScript)
- **Infrastructure**: AWS ECS Fargate, ALB, RDS, S3
- **IaC**: Terraform
- **CI/CD**: GitHub Actions

### Key Features
- Product listing, add, and delete functionality
- RESTful API with automatic documentation
- Responsive web interface
- Health check endpoints
- Automated deployments

---

## Architecture

### High-Level Architecture
```
User Browser
    ↓
S3 Static Website (Frontend)
    ↓
Application Load Balancer
    ↓
ECS Fargate (Backend Containers)
    ↓
RDS PostgreSQL (Database)
```

### AWS Resources

**Stage Environment:**
- VPC with 2 public subnets
- Application Load Balancer: stage-alb-458962299.us-east-1.elb.amazonaws.com
- ECS Cluster: stage-cluster
- ECS Service: stage-backend-blue
- RDS Database: stage-cloudshop-db
- S3 Bucket: stage-cloudshop-frontend-746669238399
- ECR Repository: stage-cloudshop-backend

**Production Environment:**
- VPC with 2 public subnets
- Application Load Balancer: prod-alb-564047131.us-east-1.elb.amazonaws.com
- ECS Cluster: prod-cluster
- ECS Service: prod-backend-blue
- RDS Database: prod-cloudshop-db
- S3 Bucket: prod-cloudshop-frontend-746669238399
- ECR Repository: prod-cloudshop-backend

### Project Structure
```
cloudshop/
├── backend/                    # FastAPI application
│   ├── app/
│   │   ├── main.py            # API routes and CORS
│   │   └── db.py              # Database connection
│   ├── tests/
│   │   └── test_main.py       # Unit tests
│   ├── Dockerfile             # Backend container
│   └── requirements.txt       # Python dependencies
├── frontend/                   # React application
│   ├── src/
│   │   └── index.js           # Main React component
│   ├── public/
│   ├── Dockerfile             # Frontend container
│   └── package.json           # Node dependencies
├── infra/                     # Terraform infrastructure
│   ├── bootstrap/             # Initial AWS setup
│   │   └── main.tf            # S3, DynamoDB, OIDC
│   ├── envs/
│   │   ├── stage/             # Stage environment
│   │   └── prod/              # Production environment
│   └── modules/               # Reusable modules
│       ├── vpc/               # VPC, subnets, IGW
│       ├── alb/               # Load balancer
│       ├── ecs/               # ECS cluster & service
│       ├── rds/               # PostgreSQL database
│       └── s3/                # S3 buckets
├── .github/workflows/         # CI/CD pipelines
│   ├── build-and-push.yml     # Build Docker images
│   ├── deploy-stage.yml       # Deploy to stage
│   ├── pr-checks.yml          # PR validation
│   └── promote-prod.yml       # Deploy to production
├── scripts/                   # Helper scripts
├── docker-compose.yml         # Local development
└── cleanup-aws.sh             # Cleanup script
```

---

## Initial Setup

### Step 1: Clone Repository
```bash
cd ~/Desktop
git clone https://github.com/AdhiJarwal/cloudshop.git
cd cloudshop
```

### Step 2: Verify Prerequisites
```bash
# Check AWS CLI
aws --version

# Check Docker
docker --version

# Check Terraform
terraform --version

# Check Node.js
node --version

# Check Python
python3 --version
```

### Step 3: Set Environment Variables
```bash
# Add to ~/.bashrc or ~/.zshrc
export AWS_ACCOUNT_ID=746669238399
export AWS_REGION=us-east-1
```

---

## Local Development

### Start Local Environment
```bash
# Start all services (PostgreSQL, Backend, Frontend)
docker-compose up

# Or start in background
docker-compose up -d

# View logs
docker-compose logs -f
```

### Access Local Application
- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:8000
- **API Documentation**: http://localhost:8000/docs
- **Health Check**: http://localhost:8000/health

### Test Local Backend
```bash
# Get products
curl http://localhost:8000/products

# Add product
curl -X POST http://localhost:8000/products \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Product","price":99.99,"description":"Test"}'

# Delete product
curl -X DELETE http://localhost:8000/products/4
```

### Stop Local Environment
```bash
docker-compose down

# Remove volumes (clean database)
docker-compose down -v
```

---

## AWS Deployment

### Phase 1: Bootstrap (One-Time Setup)

**What it creates:**
- S3 bucket for Terraform state
- DynamoDB table for state locking
- GitHub OIDC provider for CI/CD

```bash
cd infra/bootstrap
terraform init
terraform plan
terraform apply -auto-approve
```

**Verify:**
```bash
# Check S3 bucket
aws s3 ls | grep cloudshop

# Check DynamoDB table
aws dynamodb list-tables | grep terraform

# Check OIDC provider
aws iam list-open-id-connect-providers
```

### Phase 2: Deploy Stage Environment

**What it creates:**
- VPC with 2 public subnets
- Application Load Balancer
- ECS Cluster and Service
- RDS PostgreSQL database
- S3 bucket for frontend
- ECR repository for backend

```bash
cd ../envs/stage
terraform init
terraform plan -var="db_password=StagePass123"
terraform apply -auto-approve -var="db_password=StagePass123"
```

**Wait 5-10 minutes for resources to be created.**

**Get outputs:**
```bash
terraform output
```

### Phase 3: Build and Deploy Stage Backend

```bash
cd ../../../backend

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  746669238399.dkr.ecr.us-east-1.amazonaws.com

# Build image (IMPORTANT: use --platform linux/amd64 for ECS Fargate)
docker build --platform linux/amd64 \
  -t 746669238399.dkr.ecr.us-east-1.amazonaws.com/stage-cloudshop-backend:latest .

# Push to ECR
docker push 746669238399.dkr.ecr.us-east-1.amazonaws.com/stage-cloudshop-backend:latest

# Deploy to ECS
aws ecs update-service \
  --cluster stage-cluster \
  --service stage-backend-blue \
  --force-new-deployment \
  --region us-east-1

# Wait for deployment (2-3 minutes)
aws ecs wait services-stable \
  --cluster stage-cluster \
  --services stage-backend-blue \
  --region us-east-1
```

### Phase 4: Deploy Stage Frontend

```bash
cd ../frontend

# Build with API URL
export REACT_APP_API_URL=http://stage-alb-458962299.us-east-1.elb.amazonaws.com
npm install
npm run build

# Deploy to S3
aws s3 sync build/ s3://stage-cloudshop-frontend-746669238399/ --delete

# Verify upload
aws s3 ls s3://stage-cloudshop-frontend-746669238399/
```

### Phase 5: Test Stage Environment

**Access stage application:**
```
http://stage-cloudshop-frontend-746669238399.s3-website-us-east-1.amazonaws.com
```

**Test stage API:**
```bash
# Health check
curl http://stage-alb-458962299.us-east-1.elb.amazonaws.com/health

# Get products
curl http://stage-alb-458962299.us-east-1.elb.amazonaws.com/products

# Add product
curl -X POST http://stage-alb-458962299.us-east-1.elb.amazonaws.com/products \
  -H "Content-Type: application/json" \
  -d '{"name":"Stage Product","price":49.99,"description":"Testing stage"}'
```

### Phase 6: Deploy Production Environment

**Deploy infrastructure:**
```bash
cd ../../infra/envs/prod
terraform init
terraform plan -var="db_password=ProdPass456"
terraform apply -auto-approve -var="db_password=ProdPass456"
```

**Build and deploy production backend:**
```bash
cd ../../../backend

# Build production image
docker build --platform linux/amd64 \
  -t 746669238399.dkr.ecr.us-east-1.amazonaws.com/prod-cloudshop-backend:latest .

# Push to production ECR
docker push 746669238399.dkr.ecr.us-east-1.amazonaws.com/prod-cloudshop-backend:latest

# Deploy to production ECS
aws ecs update-service \
  --cluster prod-cluster \
  --service prod-backend-blue \
  --force-new-deployment \
  --region us-east-1

# Wait for deployment
aws ecs wait services-stable \
  --cluster prod-cluster \
  --services prod-backend-blue \
  --region us-east-1
```

**Deploy production frontend:**
```bash
cd ../frontend

# Build with production API URL
export REACT_APP_API_URL=http://prod-alb-564047131.us-east-1.elb.amazonaws.com
npm run build

# Deploy to production S3
aws s3 sync build/ s3://prod-cloudshop-frontend-746669238399/ --delete
```

**Access production:**
```
http://prod-cloudshop-frontend-746669238399.s3-website-us-east-1.amazonaws.com
```

---

## GitHub Actions CI/CD

### Setup GitHub Secrets

Go to: https://github.com/AdhiJarwal/cloudshop/settings/secrets/actions

**Add these secrets:**
- `AWS_ACCOUNT_ID`: 746669238399
- `STAGE_DB_PASSWORD`: StagePass123
- `PROD_DB_PASSWORD`: ProdPass456

### Create Production Environment

Go to: https://github.com/AdhiJarwal/cloudshop/settings/environments

1. Click "New environment"
2. Name: `production`
3. Add required reviewers (yourself)
4. Save

### Workflows Overview

#### 1. Build and Push Image
- **Trigger**: Automatic on push to `main`
- **What it does**: Builds Docker images and pushes to ECR
- **File**: `.github/workflows/build-and-push.yml`

#### 2. Deploy to Stage
- **Trigger**: Automatic after "Build and Push" completes
- **What it does**: Deploys new image to stage environment
- **File**: `.github/workflows/deploy-stage.yml`

#### 3. PR Checks
- **Trigger**: Automatic on Pull Requests
- **What it does**: Runs tests and validates Terraform
- **File**: `.github/workflows/pr-checks.yml`

#### 4. Promote to Production
- **Trigger**: Manual only
- **What it does**: Deploys to production environment
- **File**: `.github/workflows/promote-prod.yml`

### Typical Deployment Flow

```
1. Developer pushes code to main branch
   ↓
2. "Build and Push" workflow runs automatically
   - Builds Docker image
   - Pushes to stage ECR
   - Tags with Git commit SHA
   ↓
3. "Deploy to Stage" workflow runs automatically
   - Updates stage ECS service
   - Runs smoke tests
   ↓
4. Developer tests stage application
   - http://stage-cloudshop-frontend-746669238399.s3-website-us-east-1.amazonaws.com
   ↓
5. If stage looks good, manually trigger "Promote to Production"
   - Go to: https://github.com/AdhiJarwal/cloudshop/actions
   - Click "Promote to Production"
   - Click "Run workflow"
   - Enter image tag: latest (or Git SHA)
   - Click "Run workflow"
   ↓
6. Production is updated with zero downtime
```

### How to Promote to Production

1. **Get current Git commit:**
```bash
git log -1 --format="%H"
```

2. **Go to GitHub Actions:**
   - https://github.com/AdhiJarwal/cloudshop/actions/workflows/promote-prod.yml

3. **Run workflow:**
   - Click "Run workflow" button
   - Branch: main
   - Image tag: `latest` or Git SHA
   - Click "Run workflow"

4. **Wait for approval** (if required reviewers are set)

5. **Monitor deployment** in Actions tab

6. **Verify production** after deployment completes

---

## Testing

### Test Stage Environment

**Frontend test:**
1. Open: http://stage-cloudshop-frontend-746669238399.s3-website-us-east-1.amazonaws.com
2. Verify products load (Laptop, Mouse, Keyboard)
3. Add a new product
4. Delete a product
5. Refresh page - changes should persist

**Backend API test:**
```bash
# Health check
curl http://stage-alb-458962299.us-east-1.elb.amazonaws.com/health

# Should return: {"status":"healthy","database":"connected"}

# Get all products
curl http://stage-alb-458962299.us-east-1.elb.amazonaws.com/products

# Add product
curl -X POST http://stage-alb-458962299.us-east-1.elb.amazonaws.com/products \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Product","price":99.99,"description":"Testing"}'

# Delete product (replace 4 with actual ID)
curl -X DELETE http://stage-alb-458962299.us-east-1.elb.amazonaws.com/products/4
```

### Test Production Environment

**Same tests as stage, but use production URLs:**
- Frontend: http://prod-cloudshop-frontend-746669238399.s3-website-us-east-1.amazonaws.com
- API: http://prod-alb-564047131.us-east-1.elb.amazonaws.com

### Run Local Tests

**Backend tests:**
```bash
cd backend
pip install -r requirements.txt
pytest tests/
```

**Frontend tests:**
```bash
cd frontend
npm install
npm test
```

### Test Pull Request Workflow

```bash
# Create test branch
git checkout -b test-feature

# Make a change
echo "# Test" >> README.md

# Commit and push
git add README.md
git commit -m "Test PR checks"
git push origin test-feature

# Go to GitHub and create Pull Request
# PR checks will run automatically:
# - Backend tests
# - Frontend tests
# - Terraform validation
```

---

## Monitoring

### Check ECS Service Status

**Stage:**
```bash
aws ecs describe-services \
  --cluster stage-cluster \
  --services stage-backend-blue \
  --region us-east-1 \
  --query 'services[0].deployments[*].[status,runningCount,desiredCount]' \
  --output table
```

**Production:**
```bash
aws ecs describe-services \
  --cluster prod-cluster \
  --services prod-backend-blue \
  --region us-east-1 \
  --query 'services[0].deployments[*].[status,runningCount,desiredCount]' \
  --output table
```

### View Application Logs

**Stage backend logs:**
```bash
aws logs tail /ecs/stage/backend-blue --region us-east-1 --follow
```

**Production backend logs:**
```bash
aws logs tail /ecs/prod/backend-blue --region us-east-1 --follow
```

### Check Database Connection

**Get RDS endpoint:**
```bash
cd infra/envs/stage
terraform output db_endpoint
```

**Connect to database (requires security group access):**
```bash
psql -h stage-cloudshop-db.XXXXX.us-east-1.rds.amazonaws.com \
  -U cloudshop -d cloudshop
# Password: StagePass123
```

### Monitor Costs

**Check current month costs:**
```bash
aws ce get-cost-and-usage \
  --time-period Start=2025-11-01,End=2025-11-30 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE
```

**Estimated monthly cost per environment:** ~$55

---

## Troubleshooting

### Backend Not Responding

**Check ECS tasks:**
```bash
aws ecs list-tasks --cluster stage-cluster --region us-east-1
```

**Check task logs:**
```bash
aws logs tail /ecs/stage/backend-blue --region us-east-1 --since 10m
```

**Common issues:**
- Database connection failed: Check security groups
- Container won't start: Check CloudWatch logs
- Health check failing: Verify `/health` endpoint

### Frontend Shows "Failed to fetch"

**Issue:** Frontend can't connect to backend API

**Solution:**
```bash
cd frontend

# Rebuild with correct API URL
export REACT_APP_API_URL=http://stage-alb-458962299.us-east-1.elb.amazonaws.com
npm run build

# Redeploy
aws s3 sync build/ s3://stage-cloudshop-frontend-746669238399/ --delete

# Clear browser cache and hard refresh (Cmd+Shift+R or Ctrl+Shift+R)
```

### Deployment Stuck

**Check deployment status:**
```bash
aws ecs describe-services \
  --cluster stage-cluster \
  --services stage-backend-blue \
  --region us-east-1 \
  --query 'services[0].events[0:10]' \
  --output table
```

**Common issues:**
- Image not found: Push image to ECR first
- Health checks failing: Check application logs
- Resource limits: Check ECS task definition

### Terraform Errors

**State lock error:**
```bash
# Force unlock (use lock ID from error message)
terraform force-unlock LOCK_ID
```

**State out of sync:**
```bash
terraform refresh -var="db_password=StagePass123"
```

**Resource already exists:**
```bash
# Import existing resource
terraform import aws_s3_bucket.frontend stage-cloudshop-frontend-746669238399
```

### GitHub Actions Failing

**Build fails:**
- Check Dockerfile syntax
- Verify all files are committed
- Check GitHub secrets are set

**Deploy fails:**
- Verify AWS credentials
- Check ECR image exists
- Verify ECS service exists

**PR checks fail:**
- Run tests locally first
- Check package-lock.json is committed
- Run `terraform fmt -recursive` in infra/

---

## Cleanup

### Quick Cleanup (Recommended)

```bash
cd /Users/adhiraj.jarwal/Desktop/cloudshop
chmod +x cleanup-aws.sh
./cleanup-aws.sh
```

### Manual Cleanup

**Destroy stage environment:**
```bash
cd infra/envs/stage
terraform destroy -auto-approve -var="db_password=StagePass123"
```

**Destroy production environment:**
```bash
cd ../prod
terraform destroy -auto-approve -var="db_password=ProdPass456"
```

**Destroy bootstrap:**
```bash
cd ../../bootstrap
terraform destroy -auto-approve
```

**Verify cleanup:**
```bash
# Check ECS clusters
aws ecs list-clusters --region us-east-1

# Check RDS instances
aws rds describe-db-instances --region us-east-1

# Check S3 buckets
aws s3 ls | grep cloudshop

# Check ECR repositories
aws ecr describe-repositories --region us-east-1
```

---

## Quick Reference

### Key URLs

**Stage:**
- Frontend: http://stage-cloudshop-frontend-746669238399.s3-website-us-east-1.amazonaws.com
- API: http://stage-alb-458962299.us-east-1.elb.amazonaws.com
- Health: http://stage-alb-458962299.us-east-1.elb.amazonaws.com/health
- Docs: http://stage-alb-458962299.us-east-1.elb.amazonaws.com/docs

**Production:**
- Frontend: http://prod-cloudshop-frontend-746669238399.s3-website-us-east-1.amazonaws.com
- API: http://prod-alb-564047131.us-east-1.elb.amazonaws.com
- Health: http://prod-alb-564047131.us-east-1.elb.amazonaws.com/health
- Docs: http://prod-alb-564047131.us-east-1.elb.amazonaws.com/docs

### Key Credentials

- **AWS Account ID**: 746669238399
- **AWS Region**: us-east-1
- **Stage DB Password**: StagePass123
- **Prod DB Password**: ProdPass456

### Common Commands

```bash
# Start local development
docker-compose up

# Build and push stage backend
cd backend && docker build --platform linux/amd64 -t 746669238399.dkr.ecr.us-east-1.amazonaws.com/stage-cloudshop-backend:latest . && docker push 746669238399.dkr.ecr.us-east-1.amazonaws.com/stage-cloudshop-backend:latest

# Deploy stage backend
aws ecs update-service --cluster stage-cluster --service stage-backend-blue --force-new-deployment --region us-east-1

# Build and deploy stage frontend
cd frontend && export REACT_APP_API_URL=http://stage-alb-458962299.us-east-1.elb.amazonaws.com && npm run build && aws s3 sync build/ s3://stage-cloudshop-frontend-746669238399/ --delete

# View logs
aws logs tail /ecs/stage/backend-blue --region us-east-1 --follow

# Check service status
aws ecs describe-services --cluster stage-cluster --services stage-backend-blue --region us-east-1
```

---

## Support

For issues or questions:
1. Check [Troubleshooting](#troubleshooting) section
2. Review CloudWatch logs
3. Check GitHub Actions logs
4. Verify AWS resources in console

---

**Last Updated**: November 24, 2025
**Version**: 1.0
**Author**: CloudShop Team
