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
1. Follow [SETUP.md](SETUP.md) for detailed instructions
2. Or use [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) for step-by-step guide

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

## 🔄 Blue/Green Deployment

The project implements zero-downtime deployments:

1. **Stage**: Automatic deployment on push to `main`
2. **Production**: Manual promotion with approval
3. **Rollback**: Instant switch back to previous version
4. **Health Checks**: Automated smoke tests before traffic switch

## 🎯 Features

- ✅ Zero-downtime deployments
- ✅ Infrastructure as Code (Terraform)
- ✅ Automated CI/CD pipelines
- ✅ Cost-optimized AWS architecture
- ✅ Local development environment
- ✅ Comprehensive documentation
- ✅ Production-ready security

## 📚 Documentation

- [SETUP.md](SETUP.md) - Detailed setup instructions
- [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) - Step-by-step deployment
- [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) - Complete project overview
- [QUICKSTART.md](QUICKSTART.md) - Quick reference guide

## 💰 Cost Estimate

~$55/month per environment when running 24/7. See cost optimization tips in documentation.

## 🧹 Cleanup

```bash
# Destroy environments
cd infra/envs/stage && terraform destroy
cd infra/envs/prod && terraform destroy
cd infra/bootstrap && terraform destroy
```

## 🆘 Support

See troubleshooting sections in [SETUP.md](SETUP.md) for common issues and solutions.# Test
