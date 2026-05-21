# Runbook – StartTech Infrastructure

## Deploy Infrastructure Manually

```bash
export TF_VAR_deployer_public_key=$(cat ~/.ssh/id_rsa.pub)
./scripts/deploy-infrastructure.sh apply
```

## Trigger Backend Deployment

After pushing a new Docker image to ECR:
```bash
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name starttech-backend-asg \
  --strategy Rolling \
  --preferences MinHealthyPercentage=50,InstanceWarmup=120
```

Monitor the refresh:
```bash
aws autoscaling describe-instance-refreshes \
  --auto-scaling-group-name starttech-backend-asg \
  --query 'InstanceRefreshes[0].{Status:Status,PercentageComplete:PercentageComplete}'
```

## Roll Back Backend

```bash
# In starttech-application repo:
export ECR_REPOSITORY_NAME=starttech-backend
export AWS_REGION=us-east-1
./scripts/rollback.sh <previous-git-sha>
```

## Common Failure Modes

### Health check fails after deploy (`/ping` returns no response)

1. Check EC2 instance health in target group:
   ```bash
   aws elbv2 describe-target-health \
     --target-group-arn $(terraform output -raw target_group_arn)
   ```

2. SSH into an instance via SSM Session Manager:
   ```bash
   aws ssm start-session --target <instance-id>
   # Then check Docker container
   docker logs muchtodo-api --tail 100
   ```

3. Common causes:
   - SSM parameter missing → user-data script failed → container not started
   - ECR image not found → wrong repo name or missing `:latest` tag
   - MongoDB Atlas IP not whitelisted → container starts but health endpoint `/health` returns `{"database":"down"}`

### CloudFront returns 403 for all requests

1. Check S3 bucket policy allows CloudFront OAC service principal
2. Verify CloudFront distribution is in `Deployed` state (not `In Progress`)
3. Check that files were actually synced to S3:
   ```bash
   aws s3 ls s3://$(terraform output -raw s3_bucket_name)
   ```

### Redis connection refused (backend logs show `dial tcp: connection refused`)

1. Verify the SSM parameter `/starttech/prod/REDIS_ADDR` exists and is correct:
   ```bash
   aws ssm get-parameter --name /starttech/prod/REDIS_ADDR --query Parameter.Value --output text
   ```

2. Check ElastiCache cluster status:
   ```bash
   aws elasticache describe-replication-groups \
     --replication-group-id starttech-redis \
     --query 'ReplicationGroups[0].Status'
   ```

3. Verify `cache-sg` allows inbound 6379 from `web-sg` (check in Security Groups console)

### Backend can't reach MongoDB Atlas

1. Get NAT Gateway IPs and verify they're in Atlas IP Access List:
   ```bash
   cd terraform && terraform output nat_eip_public_ips
   ```

2. Go to MongoDB Atlas → Network Access → IP Access List → verify those IPs are listed

## Useful AWS CLI Commands

```bash
# View ASG instances
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names starttech-backend-asg \
  --query 'AutoScalingGroups[0].Instances[*].{ID:InstanceId,Health:HealthStatus,State:LifecycleState}'

# Tail backend logs in CloudWatch
aws logs tail /starttech/backend/application --follow

# Check recent CloudWatch alarms
aws cloudwatch describe-alarms \
  --alarm-name-prefix starttech \
  --query 'MetricAlarms[*].{Name:AlarmName,State:StateValue}'

# Get ECR images
aws ecr list-images --repository-name starttech-backend \
  --query 'imageIds[*].imageTag' --output table
```
