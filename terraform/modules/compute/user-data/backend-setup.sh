#!/bin/bash
set -euo pipefail

# Redirect all output to a log file for troubleshooting
exec > >(tee /var/log/user-data.log) 2>&1

echo "=== StartTech Backend Setup Starting ==="

# Update and install dependencies
yum update -y
yum install -y docker aws-cli

# Start and enable Docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Fetch region and account from instance metadata
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
AWS_REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/region)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region "$AWS_REGION")
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "Region: $AWS_REGION | Account: $ACCOUNT_ID"

# Log into ECR
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"

# Fetch secrets from SSM Parameter Store
MONGO_URI=$(aws ssm get-parameter \
  --name "/starttech/prod/MONGO_URI" \
  --with-decryption \
  --query Parameter.Value \
  --output text \
  --region "$AWS_REGION")

JWT_SECRET=$(aws ssm get-parameter \
  --name "/starttech/prod/JWT_SECRET_KEY" \
  --with-decryption \
  --query Parameter.Value \
  --output text \
  --region "$AWS_REGION")

REDIS_ADDR=$(aws ssm get-parameter \
  --name "/starttech/prod/REDIS_ADDR" \
  --query Parameter.Value \
  --output text \
  --region "$AWS_REGION" 2>/dev/null || echo "")

CLOUDFRONT_DOMAIN=$(aws ssm get-parameter \
  --name "/starttech/prod/CLOUDFRONT_DOMAIN" \
  --query Parameter.Value \
  --output text \
  --region "$AWS_REGION" 2>/dev/null || echo "")

ECR_REPO=$(aws ssm get-parameter \
  --name "/starttech/prod/ECR_REPOSITORY_NAME" \
  --query Parameter.Value \
  --output text \
  --region "$AWS_REGION" 2>/dev/null || echo "starttech-backend")

IMAGE_URI="${ECR_REGISTRY}/${ECR_REPO}:latest"

echo "Pulling image: $IMAGE_URI"
docker pull "$IMAGE_URI"

# Build ALLOWED_ORIGINS
ALLOWED_ORIGINS="http://localhost:5173"
if [ -n "$CLOUDFRONT_DOMAIN" ]; then
  ALLOWED_ORIGINS="https://${CLOUDFRONT_DOMAIN},${ALLOWED_ORIGINS}"
fi

# Only enable cache if Redis address was fetched
ENABLE_CACHE=false
if [ -n "$REDIS_ADDR" ]; then
  ENABLE_CACHE=true
fi

# Write env vars to a temp file for docker --env-file (passes as container env vars)
cat > /tmp/app.env << ENVEOF
PORT=8080
MONGO_URI=${MONGO_URI}
DB_NAME=much_todo_db
JWT_SECRET_KEY=${JWT_SECRET}
JWT_EXPIRATION_HOURS=72
ENABLE_CACHE=${ENABLE_CACHE}
REDIS_ADDR=${REDIS_ADDR}
LOG_LEVEL=INFO
LOG_FORMAT=json
SECURE_COOKIE=true
ALLOWED_ORIGINS=${ALLOWED_ORIGINS}
ENVEOF

# Stop any existing container
docker stop muchtodo-api 2>/dev/null || true
docker rm muchtodo-api 2>/dev/null || true

# Run the backend container — env vars injected via --env-file (no host file mount needed)
docker run -d \
  --name muchtodo-api \
  --restart unless-stopped \
  -p 8080:8080 \
  --env-file /tmp/app.env \
  "$IMAGE_URI"

echo "=== StartTech Backend Setup Complete ==="
