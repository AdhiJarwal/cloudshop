#!/bin/bash
set +e  # Don't exit on errors, continue cleanup

echo "🧹 CloudShop AWS Cleanup Script"
echo "================================"
echo ""
echo "This will destroy ALL AWS resources created by CloudShop:"
echo "  - ECS Clusters, Services, Tasks"
echo "  - RDS Databases (including all data)"
echo "  - Load Balancers"
echo "  - VPCs and Networking"
echo "  - S3 Buckets (including all files)"
echo "  - ECR Repositories (including all images)"
echo "  - CloudWatch Logs"
echo "  - IAM Roles"
echo "  - Terraform State"
echo ""
echo "⚠️  WARNING: This action cannot be undone!"
echo "⚠️  All data will be permanently deleted!"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "Starting cleanup process..."
echo ""

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"
echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"
echo ""

# Function to empty S3 bucket including all versions
empty_s3_bucket() {
    BUCKET=$1
    echo "  Emptying S3 bucket: $BUCKET"
    
    # Check if bucket exists
    if aws s3 ls "s3://$BUCKET" 2>/dev/null; then
        # Delete all objects
        aws s3 rm s3://$BUCKET --recursive 2>/dev/null || true
        
        # Delete all versions (if versioning enabled)
        aws s3api delete-objects --bucket $BUCKET \
            --delete "$(aws s3api list-object-versions --bucket $BUCKET \
            --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json 2>/dev/null)" \
            2>/dev/null || true
        
        # Delete all delete markers
        aws s3api delete-objects --bucket $BUCKET \
            --delete "$(aws s3api list-object-versions --bucket $BUCKET \
            --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' --output json 2>/dev/null)" \
            2>/dev/null || true
        
        echo "    ✓ Bucket emptied"
    else
        echo "    ⊘ Bucket not found or already deleted"
    fi
}

# Function to force delete ECR repository
delete_ecr_repo() {
    REPO=$1
    echo "  Deleting ECR repository: $REPO"
    aws ecr delete-repository --repository-name $REPO --force --region $AWS_REGION 2>/dev/null && echo "    ✓ Repository deleted" || echo "    ⊘ Repository not found"
}

# Function to delete CloudWatch log group
delete_log_group() {
    LOG_GROUP=$1
    echo "  Deleting log group: $LOG_GROUP"
    aws logs delete-log-group --log-group-name $LOG_GROUP --region $AWS_REGION 2>/dev/null && echo "    ✓ Log group deleted" || echo "    ⊘ Log group not found"
}

# Function to delete SSM parameter
delete_ssm_parameter() {
    PARAM=$1
    echo "  Deleting SSM parameter: $PARAM"
    aws ssm delete-parameter --name $PARAM --region $AWS_REGION 2>/dev/null && echo "    ✓ Parameter deleted" || echo "    ⊘ Parameter not found"
}

# Function to delete RDS snapshots
delete_rds_snapshots() {
    ENV=$1
    echo "  Checking for RDS snapshots: $ENV"
    SNAPSHOTS=$(aws rds describe-db-snapshots --region $AWS_REGION \
        --query "DBSnapshots[?contains(DBSnapshotIdentifier, '$ENV-cloudshop')].DBSnapshotIdentifier" \
        --output text 2>/dev/null)
    
    if [ -n "$SNAPSHOTS" ]; then
        for SNAPSHOT in $SNAPSHOTS; do
            echo "    Deleting snapshot: $SNAPSHOT"
            aws rds delete-db-snapshot --db-snapshot-identifier $SNAPSHOT --region $AWS_REGION 2>/dev/null || true
        done
        echo "    ✓ Snapshots deleted"
    else
        echo "    ⊘ No snapshots found"
    fi
}

# Step 1: Delete SSM Parameters
echo "Step 1: Deleting SSM Parameters..."
delete_ssm_parameter "/stage/backend/active_color"
delete_ssm_parameter "/prod/backend/active_color"
echo ""

# Step 2: Empty S3 buckets
echo "Step 2: Emptying S3 buckets..."
empty_s3_bucket "stage-cloudshop-frontend-$AWS_ACCOUNT_ID"
empty_s3_bucket "stage-cloudshop-data-$AWS_ACCOUNT_ID"
empty_s3_bucket "prod-cloudshop-frontend-$AWS_ACCOUNT_ID"
empty_s3_bucket "prod-cloudshop-data-$AWS_ACCOUNT_ID"
echo ""

# Step 3: Delete ECR repositories (force delete with all images)
echo "Step 3: Deleting ECR repositories..."
delete_ecr_repo "stage-cloudshop-backend"
delete_ecr_repo "prod-cloudshop-backend"
echo ""

# Step 4: Destroy Stage environment
echo "Step 4: Destroying Stage environment..."
cd infra/envs/stage
terraform destroy -auto-approve -var="db_password=StagePass123" || echo "  ⚠ Stage destroy completed with warnings"
cd ../../..
echo ""

# Step 4a: Delete Stage RDS snapshots
echo "Step 4a: Deleting Stage RDS snapshots..."
delete_rds_snapshots "stage"
echo ""

# Step 5: Destroy Production environment
echo "Step 5: Destroying Production environment..."
cd infra/envs/prod
terraform destroy -auto-approve -var="db_password=ProdPass456" || echo "  ⚠ Prod destroy completed with warnings"
cd ../../..
echo ""

# Step 5a: Delete Production RDS snapshots
echo "Step 5a: Deleting Production RDS snapshots..."
delete_rds_snapshots "prod"
echo ""

# Step 6: Delete CloudWatch Log Groups
echo "Step 6: Deleting CloudWatch Log Groups..."
delete_log_group "/ecs/stage/backend-blue"
delete_log_group "/ecs/stage/backend-green"
delete_log_group "/ecs/prod/backend-blue"
delete_log_group "/ecs/prod/backend-green"
echo ""

# Step 7: Empty Terraform state bucket
echo "Step 7: Emptying Terraform state bucket..."
empty_s3_bucket "adhi-cloudshop-terraform-state"
echo ""

# Step 8: Destroy Bootstrap
echo "Step 8: Destroying Bootstrap infrastructure..."
cd infra/bootstrap
terraform destroy -auto-approve || echo "  ⚠ Bootstrap destroy completed with warnings"
cd ../..
echo ""

# Step 9: Verification
echo "Step 9: Verifying cleanup..."
echo ""

echo "Checking remaining resources:"

# Check ECS clusters
CLUSTERS=$(aws ecs list-clusters --region $AWS_REGION --query 'clusterArns[?contains(@, `cloudshop`)]' --output text 2>/dev/null)
if [ -z "$CLUSTERS" ]; then
    echo "  ✓ No ECS clusters found"
else
    echo "  ⚠ ECS clusters still exist: $CLUSTERS"
fi

# Check RDS instances
RDS=$(aws rds describe-db-instances --region $AWS_REGION --query 'DBInstances[?contains(DBInstanceIdentifier, `cloudshop`)].DBInstanceIdentifier' --output text 2>/dev/null)
if [ -z "$RDS" ]; then
    echo "  ✓ No RDS instances found"
else
    echo "  ⚠ RDS instances still exist: $RDS"
fi

# Check S3 buckets
BUCKETS=$(aws s3 ls | grep cloudshop | awk '{print $3}')
if [ -z "$BUCKETS" ]; then
    echo "  ✓ No S3 buckets found"
else
    echo "  ⚠ S3 buckets still exist: $BUCKETS"
fi

# Check ECR repositories
ECR=$(aws ecr describe-repositories --region $AWS_REGION --query 'repositories[?contains(repositoryName, `cloudshop`)].repositoryName' --output text 2>/dev/null)
if [ -z "$ECR" ]; then
    echo "  ✓ No ECR repositories found"
else
    echo "  ⚠ ECR repositories still exist: $ECR"
fi

# Check Load Balancers
ALB=$(aws elbv2 describe-load-balancers --region $AWS_REGION --query 'LoadBalancers[?contains(LoadBalancerName, `cloudshop`) || contains(LoadBalancerName, `stage`) || contains(LoadBalancerName, `prod`)].LoadBalancerName' --output text 2>/dev/null)
if [ -z "$ALB" ]; then
    echo "  ✓ No load balancers found"
else
    echo "  ⚠ Load balancers still exist: $ALB"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ Cleanup Complete!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Destroyed resources:"
echo "  ✓ ECS Clusters, Services, and Tasks"
echo "  ✓ RDS Databases and Snapshots"
echo "  ✓ Application Load Balancers"
echo "  ✓ VPCs and Networking"
echo "  ✓ S3 Buckets and all files"
echo "  ✓ ECR Repositories and images"
echo "  ✓ CloudWatch Log Groups"
echo "  ✓ IAM Roles and OIDC Provider"
echo "  ✓ SSM Parameters"
echo "  ✓ Terraform State"
echo ""
echo "NOT affected:"
echo "  ⊘ GitHub repository (AdhiJarwal/cloudshop)"
echo "  ⊘ GitHub Actions workflows"
echo "  ⊘ GitHub Secrets"
echo "  ⊘ Local files on your computer"
echo ""
echo "💰 Cost Impact: All AWS charges will stop within 24 hours."
echo ""
echo "If you see any warnings above, you may need to manually delete"
echo "those resources from the AWS Console."
echo ""
