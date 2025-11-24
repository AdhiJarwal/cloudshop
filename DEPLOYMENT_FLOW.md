# CloudShop Deployment Flow

## 🎯 Quick Start Checklist

### ✅ Prerequisites (One-Time)
- [ ] AWS Account configured (Account ID: 746669238399)
- [ ] AWS CLI installed and configured
- [ ] Docker installed
- [ ] Terraform installed
- [ ] Node.js installed
- [ ] Git repository cloned

### ✅ Bootstrap (One-Time)
```bash
cd infra/bootstrap
terraform init
terraform apply -auto-approve
```
**Creates**: S3 state bucket, DynamoDB locks, GitHub OIDC

### ✅ Stage Deployment
```bash
# 1. Deploy infrastructure
cd infra/envs/stage
terraform init
terraform apply -auto-approve -var="db_password=StagePass123"

# 2. Build and push backend
cd ../../../backend
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 746669238399.dkr.ecr.us-east-1.amazonaws.com
docker build --platform linux/amd64 -t 746669238399.dkr.ecr.us-east-1.amazonaws.com/stage-cloudshop-backend:latest .
docker push 746669238399.dkr.ecr.us-east-1.amazonaws.com/stage-cloudshop-backend:latest
aws ecs update-service --cluster stage-cluster --service stage-backend-blue --force-new-deployment --region us-east-1

# 3. Deploy frontend
cd ../frontend
export REACT_APP_API_URL=http://stage-alb-458962299.us-east-1.elb.amazonaws.com
npm run build
aws s3 sync build/ s3://stage-cloudshop-frontend-746669238399/ --delete

# 4. Test
open http://stage-cloudshop-frontend-746669238399.s3-website-us-east-1.amazonaws.com
```

### ✅ Production Deployment
```bash
# 1. Deploy infrastructure
cd infra/envs/prod
terraform init
terraform apply -auto-approve -var="db_password=ProdPass456"

# 2. Build and push backend
cd ../../../backend
docker build --platform linux/amd64 -t 746669238399.dkr.ecr.us-east-1.amazonaws.com/prod-cloudshop-backend:latest .
docker push 746669238399.dkr.ecr.us-east-1.amazonaws.com/prod-cloudshop-backend:latest
aws ecs update-service --cluster prod-cluster --service prod-backend-blue --force-new-deployment --region us-east-1

# 3. Deploy frontend
cd ../frontend
export REACT_APP_API_URL=http://prod-alb-564047131.us-east-1.elb.amazonaws.com
npm run build
aws s3 sync build/ s3://prod-cloudshop-frontend-746669238399/ --delete

# 4. Test
open http://prod-cloudshop-frontend-746669238399.s3-website-us-east-1.amazonaws.com
```

---

## 🔄 Deployment Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    DEVELOPER WORKFLOW                        │
└─────────────────────────────────────────────────────────────┘

1. LOCAL DEVELOPMENT
   ├── docker-compose up
   ├── Make code changes
   ├── Test locally (localhost:3000)
   └── Commit changes

2. PUSH TO GITHUB
   ├── git add .
   ├── git commit -m "message"
   └── git push origin main

3. GITHUB ACTIONS (Automatic)
   ├── Build and Push Image
   │   ├── Build Docker image
   │   ├── Tag with Git SHA
   │   └── Push to stage ECR
   │
   └── Deploy to Stage
       ├── Update ECS service
       ├── Wait for healthy
       └── Run smoke tests

4. TEST STAGE
   ├── Open stage frontend
   ├── Test all features
   ├── Check API endpoints
   └── Verify database

5. PROMOTE TO PRODUCTION (Manual)
   ├── Go to GitHub Actions
   ├── Click "Promote to Production"
   ├── Enter image tag
   ├── Approve (if required)
   └── Wait for deployment

6. VERIFY PRODUCTION
   ├── Open production frontend
   ├── Test all features
   └── Monitor logs

┌─────────────────────────────────────────────────────────────┐
│                    ZERO-DOWNTIME DEPLOYMENT                  │
└─────────────────────────────────────────────────────────────┘

OLD CONTAINER (v1.0)          NEW CONTAINER (v2.0)
     │                              │
     │ Serving traffic              │
     │                              │ Starting...
     │                              │ Health checks...
     │                              │ HEALTHY ✓
     │                              │
     │ ←──── Traffic switches ────→ │
     │                              │ Now serving traffic
     │ Draining...                  │
     │ Stopped                      │
                                    │ Running v2.0

If v2.0 fails health checks:
- v1.0 continues serving traffic
- v2.0 is stopped
- No downtime!
```

---

## 🏗️ Architecture Flow

```
┌──────────────────────────────────────────────────────────────┐
│                         USER REQUEST                          │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│              S3 Static Website (Frontend)                     │
│  stage-cloudshop-frontend-746669238399.s3-website...         │
│  - React application                                          │
│  - Served as static files                                     │
└──────────────────────────────────────────────────────────────┘
                            ↓
                    API Request (fetch)
                            ↓
┌──────────────────────────────────────────────────────────────┐
│           Application Load Balancer (ALB)                     │
│  stage-alb-458962299.us-east-1.elb.amazonaws.com            │
│  - Health checks: /health every 30s                          │
│  - Routes to healthy targets only                            │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│              ECS Fargate (Backend Container)                  │
│  Cluster: stage-cluster                                       │
│  Service: stage-backend-blue                                  │
│  - FastAPI application                                        │
│  - Port 8000                                                  │
│  - Auto-scaling (min: 1, max: 3)                             │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│              RDS PostgreSQL Database                          │
│  stage-cloudshop-db.XXXXX.us-east-1.rds.amazonaws.com       │
│  - PostgreSQL 15                                              │
│  - db.t3.micro                                                │
│  - Products table                                             │
└──────────────────────────────────────────────────────────────┘
```

---

## 📊 Environment Comparison

| Feature | Stage | Production |
|---------|-------|------------|
| **Purpose** | Testing | Real users |
| **Auto-deploy** | Yes (on push to main) | No (manual only) |
| **Database** | stage-cloudshop-db | prod-cloudshop-db |
| **Frontend URL** | stage-cloudshop-frontend-746669238399 | prod-cloudshop-frontend-746669238399 |
| **API URL** | stage-alb-458962299 | prod-alb-564047131 |
| **ECR Repo** | stage-cloudshop-backend | prod-cloudshop-backend |
| **ECS Cluster** | stage-cluster | prod-cluster |
| **Can break?** | Yes, it's for testing | Should never break |
| **Data** | Test data | Real data |

---

## 🔍 Testing Checklist

### Stage Testing
- [ ] Frontend loads without errors
- [ ] Products display correctly (Laptop, Mouse, Keyboard)
- [ ] Can add new product
- [ ] Can delete product
- [ ] Changes persist after refresh
- [ ] API health check returns 200
- [ ] API docs accessible at /docs
- [ ] No CORS errors in browser console
- [ ] Backend logs show no errors

### Production Testing
- [ ] Same tests as stage
- [ ] Verify production database is separate
- [ ] Check production logs
- [ ] Monitor for 10 minutes after deployment
- [ ] Test from different browsers
- [ ] Test from mobile device

---

## 🚨 Common Issues & Solutions

### Issue: "Failed to fetch"
**Cause**: Frontend can't reach backend API
**Solution**:
```bash
cd frontend
export REACT_APP_API_URL=http://stage-alb-458962299.us-east-1.elb.amazonaws.com
npm run build
aws s3 sync build/ s3://stage-cloudshop-frontend-746669238399/ --delete
```

### Issue: ECS service won't start
**Cause**: Image not found in ECR
**Solution**:
```bash
# Push image first
cd backend
docker build --platform linux/amd64 -t 746669238399.dkr.ecr.us-east-1.amazonaws.com/stage-cloudshop-backend:latest .
docker push 746669238399.dkr.ecr.us-east-1.amazonaws.com/stage-cloudshop-backend:latest
```

### Issue: Database connection failed
**Cause**: Security group or password issue
**Solution**:
- Check security groups allow ECS → RDS
- Verify password is correct
- Check RDS is in "available" state

### Issue: GitHub Actions failing
**Cause**: Missing secrets or permissions
**Solution**:
- Verify GitHub secrets are set
- Check OIDC provider exists
- Verify IAM role has correct permissions

---

## 📝 Daily Operations

### Update Backend Code
```bash
# 1. Make changes in backend/app/
# 2. Test locally
docker-compose up

# 3. Push to GitHub
git add .
git commit -m "Update backend"
git push

# 4. GitHub Actions deploys to stage automatically
# 5. Test stage
# 6. Promote to production manually
```

### Update Frontend Code
```bash
# 1. Make changes in frontend/src/
# 2. Test locally
npm start

# 3. Push to GitHub
git add .
git commit -m "Update frontend"
git push

# 4. GitHub Actions deploys to stage automatically
# 5. Test stage
# 6. Promote to production manually
```

### View Logs
```bash
# Stage logs
aws logs tail /ecs/stage/backend-blue --region us-east-1 --follow

# Production logs
aws logs tail /ecs/prod/backend-blue --region us-east-1 --follow
```

### Check Service Health
```bash
# Stage
curl http://stage-alb-458962299.us-east-1.elb.amazonaws.com/health

# Production
curl http://prod-alb-564047131.us-east-1.elb.amazonaws.com/health
```

---

## 🎓 Learning Path

### For New Team Members

1. **Week 1: Local Development**
   - Clone repository
   - Run docker-compose
   - Understand backend API
   - Understand frontend React app
   - Make small changes locally

2. **Week 2: AWS Basics**
   - Learn about ECS, ALB, RDS, S3
   - Explore AWS Console
   - View CloudWatch logs
   - Understand Terraform code

3. **Week 3: Deployments**
   - Deploy to stage manually
   - Understand GitHub Actions
   - Test stage environment
   - Learn troubleshooting

4. **Week 4: Production**
   - Promote to production
   - Monitor production
   - Handle incidents
   - Optimize costs

---

## 📚 Additional Resources

- **AWS Documentation**: https://docs.aws.amazon.com/
- **Terraform Docs**: https://www.terraform.io/docs
- **FastAPI Docs**: https://fastapi.tiangolo.com/
- **React Docs**: https://react.dev/
- **GitHub Actions**: https://docs.github.com/en/actions

---

**Quick Links:**
- [Complete Guide](COMPLETE_GUIDE.md) - Full documentation
- [README](README.md) - Project overview
- [RUN_PROJECT.md](RUN_PROJECT.md) - All commands
- [Troubleshooting](COMPLETE_GUIDE.md#troubleshooting) - Common issues
