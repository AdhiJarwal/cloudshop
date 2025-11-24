# How to Run CloudShop - Complete Guide

## Prerequisites
- AWS Account (ID: 746669238399)
- AWS CLI configured
- Docker installed
- Terraform installed
- Node.js installed
- GitHub repo: AdhiJarwal/cloudshop

## 🏠 LOCAL DEVELOPMENT

### 1. Start Everything Locally
```bash
cd /Users/adhiraj.jarwal/Desktop/cloudshop
docker-compose up
```

**Access:**
- Frontend: http://localhost:3000
- Backend API: http://localhost:8000
- API Docs: http://localhost:8000/docs

### 2. Stop Local Environment
```bash
docker-compose down
```

---

## ☁️ AWS DEPLOYMENT

### STEP 1: Bootstrap (One-time setup)
```bash
cd infra/bootstrap
terraform init
terraform apply -auto-approve
```

**Creates:**
- S3 bucket: adhi-cloudshop-terraform-state
- DynamoDB table: terraform-state-locks
- GitHub OIDC provider

### STEP 2: Deploy Stage Environment
```bash
cd ../envs/stage
terraform init
terraform apply -auto-approve -var="db_password=StagePass123"
```

**Wait 5-10 minutes for:**
- VPC, subnets, ALB
- ECS cluster and service
- RDS PostgreSQL database
- S3 buckets

### STEP 3: Build and Push Backend Docker Image
```bash
cd ../../../backend

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 746669238399.dkr.ecr.us-east-1.amazonaws.com

# Build for x86_64 (ECS Fargate)
docker build --platform linux/amd64 -t 746669238399.dkr.ecr.us-east-1.amazonaws.com/stage-cloudshop-backend:latest .

# Push to ECR
docker push 746669238399.dkr.ecr.us-east-1.amazonaws.com/stage-cloudshop-backend:latest
```

### STEP 4: Deploy Backend to ECS
```bash
# Force ECS to pull new image
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

### STEP 5: Test Backend API
```bash
# Get ALB DNS
ALB_DNS=$(cd infra/envs/stage && terraform output -raw alb_dns_name)

# Test health
curl http://$ALB_DNS/health

# Test products
curl http://$ALB_DNS/products
```

**Expected:** JSON with 3 products (Laptop, Mouse, Keyboard)

### STEP 6: Build and Deploy Frontend
```bash
cd ../frontend

# Build with API URL
export REACT_APP_API_URL=http://stage-alb-458962299.us-east-1.elb.amazonaws.com
npm run build

# Deploy to S3
aws s3 sync build/ s3://stage-cloudshop-frontend-746669238399/ --delete
```

### STEP 7: Access Stage Application
```
http://stage-cloudshop-frontend-746669238399.s3-website-us-east-1.amazonaws.com
```

**Hard refresh:** Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows)

---

## 🚀 PRODUCTION DEPLOYMENT

### Deploy Production Environment
```bash
cd infra/envs/prod
terraform init
terraform apply -auto-approve -var="db_password=ProdPass456"
```

### Build and Push Production Backend
```bash
cd ../../../backend

docker build --platform linux/amd64 -t 746669238399.dkr.ecr.us-east-1.amazonaws.com/prod-cloudshop-backend:latest .
docker push 746669238399.dkr.ecr.us-east-1.amazonaws.com/prod-cloudshop-backend:latest

aws ecs update-service \
  --cluster prod-cluster \
  --service prod-backend-blue \
  --force-new-deployment \
  --region us-east-1
```

### Deploy Production Frontend
```bash
cd ../frontend

export REACT_APP_API_URL=http://prod-alb-XXXXXXXXX.us-east-1.elb.amazonaws.com
npm run build
aws s3 sync build/ s3://prod-cloudshop-frontend-746669238399/ --delete
```

---

## 🔄 UPDATE APPLICATION

### Update Backend Code
```bash
# 1. Make code changes in backend/app/

# 2. Rebuild and push
cd backend
docker build --platform linux/amd64 -t 746669238399.dkr.ecr.us-east-1.amazonaws.com/stage-cloudshop-backend:latest .
docker push 746669238399.dkr.ecr.us-east-1.amazonaws.com/stage-cloudshop-backend:latest

# 3. Deploy to ECS
aws ecs update-service --cluster stage-cluster --service stage-backend-blue --force-new-deployment --region us-east-1

# 4. Wait 2-3 minutes for deployment
```

### Update Frontend Code
```bash
# 1. Make code changes in frontend/src/

# 2. Rebuild and deploy
cd frontend
export REACT_APP_API_URL=http://stage-alb-458962299.us-east-1.elb.amazonaws.com
npm run build
aws s3 sync build/ s3://stage-cloudshop-frontend-746669238399/ --delete

# 3. Hard refresh browser
```

---

## 🧪 TESTING

### Test Backend Locally
```bash
cd backend
docker-compose up postgres -d
sleep 5
python -m pytest
```

### Test Frontend Locally
```bash
cd frontend
npm test
```

### Test API Endpoints
```bash
# Health check
curl http://stage-alb-458962299.us-east-1.elb.amazonaws.com/health

# Get products
curl http://stage-alb-458962299.us-east-1.elb.amazonaws.com/products

# Add product
curl -X POST http://stage-alb-458962299.us-east-1.elb.amazonaws.com/products \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Product","price":99.99,"description":"Test"}'

# Delete product
curl -X DELETE http://stage-alb-458962299.us-east-1.elb.amazonaws.com/products/4
```

---

## 📊 MONITORING

### Check ECS Service Status
```bash
aws ecs describe-services \
  --cluster stage-cluster \
  --services stage-backend-blue \
  --region us-east-1 \
  --query 'services[0].deployments[*].[status,runningCount,desiredCount]' \
  --output table
```

### View Backend Logs
```bash
aws logs tail /ecs/stage/backend-blue --region us-east-1 --follow
```

### Check RDS Database
```bash
# Get RDS endpoint
cd infra/envs/stage
terraform output db_endpoint

# Connect (from EC2 or local with security group access)
psql -h stage-cloudshop-db.XXXXX.us-east-1.rds.amazonaws.com -U cloudshop -d cloudshop
# Password: StagePass123
```

---

## 🧹 CLEANUP

### Destroy Everything
```bash
# Run cleanup script
cd /Users/adhiraj.jarwal/Desktop/cloudshop
chmod +x cleanup-aws.sh
./cleanup-aws.sh
```

### Manual Cleanup
```bash
# Destroy stage
cd infra/envs/stage
terraform destroy -auto-approve -var="db_password=StagePass123"

# Destroy prod
cd ../prod
terraform destroy -auto-approve -var="db_password=ProdPass456"

# Destroy bootstrap
cd ../../bootstrap
terraform destroy -auto-approve
```

---

## 🔑 IMPORTANT CREDENTIALS

- **AWS Account ID:** 746669238399
- **Stage DB Password:** StagePass123
- **Prod DB Password:** ProdPass456
- **Region:** us-east-1

## 📦 KEY RESOURCES

**Stage:**
- ALB: http://stage-alb-458962299.us-east-1.elb.amazonaws.com
- Frontend: http://stage-cloudshop-frontend-746669238399.s3-website-us-east-1.amazonaws.com
- ECR: 746669238399.dkr.ecr.us-east-1.amazonaws.com/stage-cloudshop-backend
- ECS Cluster: stage-cluster
- ECS Service: stage-backend-blue

**Production:**
- Similar naming with "prod" prefix

## 🐛 TROUBLESHOOTING

### Backend not responding
```bash
# Check ECS tasks
aws ecs list-tasks --cluster stage-cluster --region us-east-1

# Check logs
aws logs tail /ecs/stage/backend-blue --region us-east-1 --since 10m
```

### Frontend shows "Failed to fetch"
```bash
# Rebuild with correct API URL
cd frontend
export REACT_APP_API_URL=http://stage-alb-458962299.us-east-1.elb.amazonaws.com
npm run build
aws s3 sync build/ s3://stage-cloudshop-frontend-746669238399/ --delete
```

### Database connection issues
- Check security groups allow ECS to RDS
- Verify password is correct
- Check RDS is in "available" state

---

## 🎯 QUICK COMMANDS

```bash
# Full local restart
docker-compose down && docker-compose up

# Quick backend update
cd backend && docker build --platform linux/amd64 -t 746669238399.dkr.ecr.us-east-1.amazonaws.com/stage-cloudshop-backend:latest . && docker push 746669238399.dkr.ecr.us-east-1.amazonaws.com/stage-cloudshop-backend:latest && aws ecs update-service --cluster stage-cluster --service stage-backend-blue --force-new-deployment --region us-east-1

# Quick frontend update
cd frontend && export REACT_APP_API_URL=http://stage-alb-458962299.us-east-1.elb.amazonaws.com && npm run build && aws s3 sync build/ s3://stage-cloudshop-frontend-746669238399/ --delete

# Check deployment status
aws ecs describe-services --cluster stage-cluster --services stage-backend-blue --region us-east-1 --query 'services[0].deployments[?status==`PRIMARY`].runningCount'

# View logs
aws logs tail /ecs/stage/backend-blue --region us-east-1 --follow
```
