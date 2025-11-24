# CloudShop Setup Guide

## Prerequisites

1. AWS Account with CLI configured
2. GitHub account and repository
3. Terraform >= 1.0
4. Docker Desktop
5. Node.js >= 18
6. Python >= 3.11

## Step 1: Bootstrap AWS Infrastructure

```bash
cd infra/bootstrap
terraform init
terraform apply
```

Note the outputs, especially `github_role_arn`.

**Important**: Edit `infra/bootstrap/main.tf` and replace `YOUR_GITHUB_USERNAME` with your actual GitHub username.

## Step 2: Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add these secrets:
- `AWS_ACCOUNT_ID`: Your AWS account ID
- `STAGE_DB_PASSWORD`: Strong password for stage database
- `PROD_DB_PASSWORD`: Strong password for prod database

## Step 3: Create GitHub Environment

Go to Settings → Environments → New environment

Create environment named `production` and add protection rules:
- Required reviewers (add yourself)

## Step 4: Initial Deployment

### Deploy Stage Infrastructure

```bash
cd infra/envs/stage
terraform init
terraform apply \
  -var="db_password=YOUR_STAGE_PASSWORD"
```

This creates:
- VPC with public subnets
- ECS cluster with blue/green services
- ALB with target groups
- RDS Postgres database
- S3 buckets
- ECR repository

### Build and Push Initial Image

```bash
cd backend
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
docker build -t YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/stage-cloudshop-backend:latest .
docker push YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/stage-cloudshop-backend:latest
```

### Update ECS Service

```bash
cd infra/envs/stage
terraform apply \
  -var="backend_image_tag=latest" \
  -var="db_password=YOUR_STAGE_PASSWORD"
```

## Step 5: Test Stage

Get ALB DNS:
```bash
cd infra/envs/stage
terraform output alb_dns_name
```

Test API:
```bash
curl http://YOUR_ALB_DNS/health
curl http://YOUR_ALB_DNS/products
```

## Step 6: Deploy Frontend

```bash
cd frontend
npm install
npm run build

# Upload to S3
BUCKET=$(terraform -chdir=../infra/envs/stage output -raw frontend_bucket)
aws s3 sync build/ s3://$BUCKET/
```

## Step 7: CI/CD Workflow

Now that infrastructure is ready:

1. Push code to `main` branch
2. `build-and-push.yml` builds Docker image
3. `deploy-stage.yml` deploys to stage with blue/green
4. Test stage environment
5. Trigger `promote-prod.yml` manually with image tag
6. Approve in GitHub UI
7. Production deploys with blue/green

## Step 8: Deploy Production

```bash
cd infra/envs/prod
terraform init
terraform apply \
  -var="db_password=YOUR_PROD_PASSWORD"
```

Then use GitHub Actions to promote stage image to prod.

## Local Development

```bash
docker-compose up
```

This starts:
- Postgres on port 5432
- Backend on port 8000
- Frontend on port 3000

## Troubleshooting

### ECS tasks not starting
- Check CloudWatch logs: `/ecs/stage/backend-blue`
- Verify security groups allow traffic
- Check RDS is accessible

### Database connection errors
- Ensure RDS security group allows ECS security group
- Verify DB credentials in task definition
- Check RDS is publicly accessible (for public subnets)

### Blue/Green deployment stuck
- Check ECS service events in AWS Console
- Verify target group health checks
- Review ALB listener rules

## Cost Optimization

To minimize costs:
- Stop RDS instances when not in use
- Reduce ECS desired count to 0
- Delete unused ECR images
- Use `terraform destroy` for environments not in use

## Cleanup

```bash
# Destroy stage
cd infra/envs/stage
terraform destroy

# Destroy prod
cd infra/envs/prod
terraform destroy

# Destroy bootstrap (last)
cd infra/bootstrap
terraform destroy
```
