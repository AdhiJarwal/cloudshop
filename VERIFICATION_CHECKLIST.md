# CloudShop Verification Checklist

Use this checklist to verify everything is working correctly.

---

## ✅ Local Development

### Docker Compose
- [ ] `docker-compose up` starts without errors
- [ ] PostgreSQL container is healthy
- [ ] Backend container is healthy
- [ ] Frontend container is healthy
- [ ] Can access http://localhost:3000
- [ ] Can access http://localhost:8000
- [ ] Can access http://localhost:8000/docs
- [ ] Products load in frontend
- [ ] Can add products
- [ ] Can delete products
- [ ] Changes persist after refresh

### Local Testing
```bash
# Test backend
curl http://localhost:8000/health
curl http://localhost:8000/products

# Test adding product
curl -X POST http://localhost:8000/products \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","price":99.99,"description":"Test"}'
```

---

## ✅ AWS Bootstrap

### Terraform State
- [ ] S3 bucket exists: `adhi-cloudshop-terraform-state`
- [ ] DynamoDB table exists: `terraform-state-locks`
- [ ] Can run `terraform init` in envs/stage
- [ ] Can run `terraform init` in envs/prod

### GitHub OIDC
- [ ] OIDC provider exists in IAM
- [ ] IAM role `github-actions-role` exists
- [ ] Role has correct trust policy for GitHub

**Verify:**
```bash
aws s3 ls | grep cloudshop
aws dynamodb list-tables | grep terraform
aws iam list-open-id-connect-providers
aws iam get-role --role-name github-actions-role
```

---

## ✅ Stage Environment

### Infrastructure
- [ ] VPC exists with 2 public subnets
- [ ] Internet Gateway attached
- [ ] Route tables configured
- [ ] Security groups created
- [ ] ALB exists: stage-alb-458962299
- [ ] Target groups created
- [ ] ECS cluster exists: stage-cluster
- [ ] ECS service exists: stage-backend-blue
- [ ] RDS instance exists: stage-cloudshop-db
- [ ] RDS status is "available"
- [ ] S3 bucket exists: stage-cloudshop-frontend-746669238399
- [ ] ECR repository exists: stage-cloudshop-backend

**Verify:**
```bash
cd infra/envs/stage
terraform output

aws ecs list-clusters --region us-east-1
aws ecs list-services --cluster stage-cluster --region us-east-1
aws rds describe-db-instances --region us-east-1
aws s3 ls | grep stage
aws ecr describe-repositories --region us-east-1
```

### Backend Deployment
- [ ] Docker image exists in ECR
- [ ] ECS task is running
- [ ] Task passes health checks
- [ ] ALB target is healthy
- [ ] Can access health endpoint
- [ ] Can access products endpoint
- [ ] Can access API docs

**Verify:**
```bash
# Check image
aws ecr describe-images --repository-name stage-cloudshop-backend --region us-east-1

# Check ECS
aws ecs describe-services --cluster stage-cluster --services stage-backend-blue --region us-east-1

# Check health
curl http://stage-alb-458962299.us-east-1.elb.amazonaws.com/health
curl http://stage-alb-458962299.us-east-1.elb.amazonaws.com/products
curl http://stage-alb-458962299.us-east-1.elb.amazonaws.com/docs
```

### Frontend Deployment
- [ ] Files uploaded to S3
- [ ] S3 website hosting enabled
- [ ] index.html exists
- [ ] JavaScript files exist
- [ ] Can access frontend URL
- [ ] No 404 errors
- [ ] No CORS errors in console

**Verify:**
```bash
# Check S3
aws s3 ls s3://stage-cloudshop-frontend-746669238399/

# Access frontend
open http://stage-cloudshop-frontend-746669238399.s3-website-us-east-1.amazonaws.com
```

### End-to-End Testing
- [ ] Frontend loads without errors
- [ ] Products display (Laptop, Mouse, Keyboard)
- [ ] Can add new product
- [ ] New product appears in list
- [ ] Can delete product
- [ ] Product removed from list
- [ ] Refresh page - changes persist
- [ ] No errors in browser console
- [ ] No errors in backend logs

**Test:**
```bash
# View logs
aws logs tail /ecs/stage/backend-blue --region us-east-1 --follow
```

---

## ✅ Production Environment

### Infrastructure
- [ ] VPC exists with 2 public subnets
- [ ] ALB exists: prod-alb-564047131
- [ ] ECS cluster exists: prod-cluster
- [ ] ECS service exists: prod-backend-blue
- [ ] RDS instance exists: prod-cloudshop-db
- [ ] S3 bucket exists: prod-cloudshop-frontend-746669238399
- [ ] ECR repository exists: prod-cloudshop-backend

**Verify:**
```bash
cd infra/envs/prod
terraform output

aws ecs list-services --cluster prod-cluster --region us-east-1
```

### Backend Deployment
- [ ] Docker image exists in production ECR
- [ ] ECS task is running
- [ ] Task passes health checks
- [ ] Can access health endpoint
- [ ] Can access products endpoint

**Verify:**
```bash
aws ecr describe-images --repository-name prod-cloudshop-backend --region us-east-1

curl http://prod-alb-564047131.us-east-1.elb.amazonaws.com/health
curl http://prod-alb-564047131.us-east-1.elb.amazonaws.com/products
```

### Frontend Deployment
- [ ] Files uploaded to production S3
- [ ] Can access production frontend URL
- [ ] No errors in console

**Verify:**
```bash
aws s3 ls s3://prod-cloudshop-frontend-746669238399/

open http://prod-cloudshop-frontend-746669238399.s3-website-us-east-1.amazonaws.com
```

### End-to-End Testing
- [ ] Production frontend loads
- [ ] Products display correctly
- [ ] Can add products
- [ ] Can delete products
- [ ] Changes persist
- [ ] No errors in logs

---

## ✅ GitHub Actions

### Secrets Configuration
- [ ] AWS_ACCOUNT_ID secret exists
- [ ] STAGE_DB_PASSWORD secret exists
- [ ] PROD_DB_PASSWORD secret exists

**Verify:**
Go to: https://github.com/AdhiJarwal/cloudshop/settings/secrets/actions

### Environment Configuration
- [ ] Production environment exists
- [ ] Required reviewers configured (optional)

**Verify:**
Go to: https://github.com/AdhiJarwal/cloudshop/settings/environments

### Workflows
- [ ] Build and Push workflow exists
- [ ] Deploy to Stage workflow exists
- [ ] PR Checks workflow exists
- [ ] Promote to Production workflow exists

**Verify:**
Go to: https://github.com/AdhiJarwal/cloudshop/actions

### Workflow Testing

#### Test Build and Push
```bash
# Make a change
echo "# Test" >> README.md
git add README.md
git commit -m "Test build workflow"
git push origin main

# Check GitHub Actions
# Should see "Build and Push" running
```
- [ ] Build workflow triggers on push
- [ ] Docker image builds successfully
- [ ] Image pushed to ECR
- [ ] Tagged with Git SHA

#### Test Deploy to Stage
- [ ] Deploy workflow triggers after build
- [ ] Terraform applies successfully
- [ ] ECS service updates
- [ ] Service becomes stable
- [ ] Smoke tests pass

#### Test PR Checks
```bash
# Create test branch
git checkout -b test-pr
echo "# Test PR" >> README.md
git add README.md
git commit -m "Test PR checks"
git push origin test-pr

# Create PR on GitHub
```
- [ ] Backend tests run
- [ ] Frontend tests run
- [ ] Terraform validation runs
- [ ] All checks pass

#### Test Promote to Production
- [ ] Can trigger workflow manually
- [ ] Can enter image tag
- [ ] Workflow runs successfully
- [ ] Production updates
- [ ] No downtime

---

## ✅ Monitoring & Logs

### CloudWatch Logs
- [ ] Stage backend log group exists: `/ecs/stage/backend-blue`
- [ ] Production backend log group exists: `/ecs/prod/backend-blue`
- [ ] Logs are being written
- [ ] No error messages

**Verify:**
```bash
aws logs tail /ecs/stage/backend-blue --region us-east-1 --since 5m
aws logs tail /ecs/prod/backend-blue --region us-east-1 --since 5m
```

### ECS Metrics
- [ ] CPU utilization is normal (<80%)
- [ ] Memory utilization is normal (<80%)
- [ ] Task count matches desired count

**Verify:**
```bash
aws ecs describe-services --cluster stage-cluster --services stage-backend-blue --region us-east-1
aws ecs describe-services --cluster prod-cluster --services prod-backend-blue --region us-east-1
```

### ALB Health Checks
- [ ] Stage targets are healthy
- [ ] Production targets are healthy
- [ ] Health check interval is 30 seconds
- [ ] Healthy threshold is 2

**Verify:**
```bash
aws elbv2 describe-target-health --target-group-arn <stage-target-group-arn>
aws elbv2 describe-target-health --target-group-arn <prod-target-group-arn>
```

---

## ✅ Security

### IAM Roles
- [ ] ECS task execution role exists
- [ ] ECS task role exists
- [ ] GitHub Actions role exists
- [ ] Roles have minimum required permissions

### Security Groups
- [ ] ALB security group allows HTTP (80)
- [ ] ECS security group allows traffic from ALB
- [ ] RDS security group allows traffic from ECS
- [ ] No unnecessary ports open

### Secrets
- [ ] Database passwords are not in code
- [ ] Database passwords are in GitHub Secrets
- [ ] No credentials in logs
- [ ] No credentials in frontend code

---

## ✅ Cost Optimization

### Resource Sizing
- [ ] ECS tasks use appropriate CPU/memory
- [ ] RDS instance is right-sized (db.t3.micro)
- [ ] No unused resources running
- [ ] Auto-scaling configured

### Cost Monitoring
- [ ] Can view current costs
- [ ] Estimated monthly cost is ~$55 per environment
- [ ] No unexpected charges

**Verify:**
```bash
aws ce get-cost-and-usage \
  --time-period Start=2025-11-01,End=2025-11-30 \
  --granularity MONTHLY \
  --metrics BlendedCost
```

---

## ✅ Documentation

### Files Exist
- [ ] README.md
- [ ] COMPLETE_GUIDE.md
- [ ] DEPLOYMENT_FLOW.md
- [ ] RUN_PROJECT.md
- [ ] VERIFICATION_CHECKLIST.md (this file)
- [ ] cleanup-aws.sh

### Documentation Quality
- [ ] All URLs are correct
- [ ] All commands work
- [ ] No outdated information
- [ ] Easy to follow for new team members

---

## ✅ Disaster Recovery

### Backup Strategy
- [ ] RDS automated backups enabled
- [ ] Backup retention period set
- [ ] Can restore from backup

### Rollback Plan
- [ ] Know how to rollback deployment
- [ ] Previous Docker images are tagged
- [ ] Can switch to previous version quickly

**Rollback procedure:**
```bash
# Get previous image tag
aws ecr describe-images --repository-name stage-cloudshop-backend --region us-east-1

# Update task definition with previous image
# Force new deployment
aws ecs update-service --cluster stage-cluster --service stage-backend-blue --force-new-deployment --region us-east-1
```

---

## ✅ Final Checks

### Stage Environment
- [ ] ✅ Infrastructure deployed
- [ ] ✅ Backend running
- [ ] ✅ Frontend deployed
- [ ] ✅ Database accessible
- [ ] ✅ End-to-end tests pass
- [ ] ✅ No errors in logs

### Production Environment
- [ ] ✅ Infrastructure deployed
- [ ] ✅ Backend running
- [ ] ✅ Frontend deployed
- [ ] ✅ Database accessible
- [ ] ✅ End-to-end tests pass
- [ ] ✅ No errors in logs

### CI/CD
- [ ] ✅ All workflows configured
- [ ] ✅ Secrets set
- [ ] ✅ Workflows tested
- [ ] ✅ All checks passing

### Documentation
- [ ] ✅ All docs created
- [ ] ✅ All commands verified
- [ ] ✅ Team can follow guides

---

## 🎉 Success Criteria

Your CloudShop deployment is successful when:

1. ✅ Local development works
2. ✅ Stage environment is fully functional
3. ✅ Production environment is fully functional
4. ✅ GitHub Actions workflows run successfully
5. ✅ Can add/delete products in both environments
6. ✅ Zero downtime during deployments
7. ✅ All documentation is complete
8. ✅ Team members can deploy independently

---

## 📞 Support

If any checklist item fails:
1. Check [COMPLETE_GUIDE.md](COMPLETE_GUIDE.md) troubleshooting section
2. Review CloudWatch logs
3. Check GitHub Actions logs
4. Verify AWS resources in console

---

**Last Updated**: November 24, 2025
