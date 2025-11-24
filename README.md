# CloudShop - AWS Blue/Green Deployment Demo

A complete e-commerce application demonstrating blue/green deployment on AWS using ECS Fargate, Terraform, and GitHub Actions.

## 🏗️ Architecture

- **Backend**: FastAPI with PostgreSQL
- **Frontend**: React SPA hosted on S3
- **Infrastructure**: ECS Fargate, ALB, RDS, S3
- **Deployment**: Blue/Green with GitHub Actions
- **IaC**: Terraform modules for reusable infrastructure

## 🚀 Quick Start

### Local Development
```bash
docker-compose up
```
- Backend: http://localhost:8000
- Frontend: http://localhost:3000
- API Docs: http://localhost:8000/docs

### AWS Deployment

**See [RUN_PROJECT.md](RUN_PROJECT.md) for complete step-by-step commands**

1. **Bootstrap** (one-time):
```bash
cd infra/bootstrap && terraform init && terraform apply -auto-approve
```

2. **Deploy Stage**:
```bash
cd infra/envs/stage && terraform init && terraform apply -auto-approve -var="db_password=StagePass123"
```

3. **Build & Push Backend**:
```bash
cd backend
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 746669238399.dkr.ecr.us-east-1.amazonaws.com
docker build --platform linux/amd64 -t 746669238399.dkr.ecr.us-east-1.amazonaws.com/stage-cloudshop-backend:latest .
docker push 746669238399.dkr.ecr.us-east-1.amazonaws.com/stage-cloudshop-backend:latest
aws ecs update-service --cluster stage-cluster --service stage-backend-blue --force-new-deployment --region us-east-1
```

4. **Deploy Frontend**:
```bash
cd frontend
export REACT_APP_API_URL=http://stage-alb-458962299.us-east-1.elb.amazonaws.com
npm run build
aws s3 sync build/ s3://stage-cloudshop-frontend-746669238399/ --delete
```

5. **Access Stage**: http://stage-cloudshop-frontend-746669238399.s3-website-us-east-1.amazonaws.com

## 📁 Project Structure

```
cloudshop/
├── backend/              # FastAPI application
├── frontend/             # React application  
├── infra/               # Terraform infrastructure
│   ├── modules/         # Reusable Terraform modules
│   ├── envs/           # Environment-specific configs
│   └── bootstrap/      # Initial AWS setup
├── .github/workflows/   # CI/CD pipelines
├── data-pipeline/      # Lambda and ETL jobs
└── scripts/           # Helper scripts
```

## 🔄 CI/CD with GitHub Actions

### Automated Workflows

1. **Build and Push Image** (automatic on push to `main`):
   - Builds Docker images
   - Pushes to Amazon ECR
   - Tags with Git commit SHA

2. **Deploy to Stage** (automatic after build):
   - Deploys to stage environment
   - Updates ECS service
   - Runs smoke tests

3. **PR Checks** (automatic on Pull Requests):
   - Runs backend tests
   - Runs frontend tests
   - Validates Terraform

4. **Promote to Production** (manual trigger):
   - Go to: https://github.com/AdhiJarwal/cloudshop/actions
   - Click "Promote to Production"
   - Click "Run workflow"
   - Enter image tag (Git SHA or `latest`)
   - Deploys to production

### Typical Workflow
```
Push to main → Build → Deploy Stage → Test → Manually Promote to Prod
```

## 🎯 Features

- ✅ Zero-downtime deployments
- ✅ Infrastructure as Code (Terraform)
- ✅ Automated CI/CD pipelines
- ✅ Cost-optimized AWS architecture
- ✅ Local development environment
- ✅ Comprehensive documentation
- ✅ Production-ready security

## 📚 Documentation

### 🌟 Start Here
- **[COMPLETE_GUIDE.md](COMPLETE_GUIDE.md)** - Complete guide from setup to production ⭐⭐⭐
- **[DEPLOYMENT_FLOW.md](DEPLOYMENT_FLOW.md)** - Visual deployment flow and checklists ⭐⭐
- **[RUN_PROJECT.md](RUN_PROJECT.md)** - All commands in one place ⭐

### 📖 Additional Guides
- [README.md](README.md) - This file (project overview)
- [SETUP.md](SETUP.md) - Detailed setup instructions
- [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) - Step-by-step deployment
- [COMPLETE_DEPLOYMENT_GUIDE.md](COMPLETE_DEPLOYMENT_GUIDE.md) - Full deployment guide
- [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) - Complete project overview
- [QUICKSTART.md](QUICKSTART.md) - Quick reference guide

## 💰 Cost Estimate

~$55/month per environment when running 24/7. See cost optimization tips in documentation.

## 🧹 Cleanup

```bash
# Quick cleanup script
./cleanup-aws.sh

# Or manual cleanup
cd infra/envs/stage && terraform destroy -auto-approve -var="db_password=StagePass123"
cd ../prod && terraform destroy -auto-approve -var="db_password=ProdPass456"
cd ../../bootstrap && terraform destroy -auto-approve
```

## 🔑 Key Information

- **AWS Account ID**: 746669238399
- **Region**: us-east-1
- **Stage DB Password**: StagePass123
- **Prod DB Password**: ProdPass456
- **Stage Frontend**: http://stage-cloudshop-frontend-746669238399.s3-website-us-east-1.amazonaws.com
- **Stage API**: http://stage-alb-458962299.us-east-1.elb.amazonaws.com

## 🐛 Troubleshooting

### Backend not responding
```bash
aws logs tail /ecs/stage/backend-blue --region us-east-1 --follow
```

### Frontend shows errors
```bash
# Rebuild with correct API URL
cd frontend
export REACT_APP_API_URL=http://stage-alb-458962299.us-east-1.elb.amazonaws.com
npm run build
aws s3 sync build/ s3://stage-cloudshop-frontend-746669238399/ --delete
```

### Check deployment status
```bash
aws ecs describe-services --cluster stage-cluster --services stage-backend-blue --region us-east-1
```

## 🆘 Support

See troubleshooting sections in [SETUP.md](SETUP.md) for common issues and solutions.# Test
