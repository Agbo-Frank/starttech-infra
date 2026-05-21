# starttech-infra

Infrastructure as Code for the StartTech application stack, managed with Terraform and deployed via GitHub Actions.

## Architecture Overview

```
Internet
    │
    ├── CloudFront (CDN) → S3 (React SPA)
    │
    └── ALB (port 80/443)
             │
        ASG (EC2 private subnets)
             │
        ┌────┴────┐
   ElastiCache   MongoDB Atlas (external)
    (Redis)
```

All backend EC2 instances run in private subnets. Traffic flows: Internet → ALB (public subnets) → EC2 (private subnets). Outbound internet access for EC2 is via NAT Gateways.

## Repository Structure

```
starttech-infra/
├── .github/workflows/
│   └── infrastructure-deploy.yml   # Terraform plan on PR, apply on merge
├── terraform/
│   ├── main.tf                     # Root: wires all modules + S3 backend
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example    # Template – copy to terraform.tfvars
│   └── modules/
│       ├── networking/             # VPC, subnets, IGW, NAT GWs, SGs
│       ├── compute/                # ASG, ALB, ECR, IAM, Launch Template
│       ├── storage/                # S3, CloudFront, ElastiCache, SSM params
│       └── monitoring/             # CloudWatch logs, alarms, SNS, dashboard
├── monitoring/
│   ├── cloudwatch-dashboard.json   # Dashboard widget definitions (reference)
│   ├── alarm-definitions.json      # Alarm parameters (reference)
│   └── log-insights-queries.txt    # Saved Logs Insights queries
├── scripts/
│   └── deploy-infrastructure.sh    # Local wrapper for terraform commands
├── ARCHITECTURE.md
└── RUNBOOK.md
```

## Prerequisites (One-Time Manual Setup)

### 1. Terraform State Backend
```bash
# Create S3 bucket for state (replace with your account ID)
aws s3api create-bucket \
  --bucket starttech-terraform-state \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket starttech-terraform-state \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket starttech-terraform-state \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

### 2. Update Backend Configuration
Edit `terraform/main.tf` and update the `backend "s3"` block with your actual bucket name (include your account ID to make it globally unique).

### 3. GitHub Secrets (for starttech-infra repo)
| Secret | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |
| `AWS_REGION` | AWS region (e.g. `us-east-1`) |
| `TF_VAR_deployer_public_key` | Your SSH public key (contents of `~/.ssh/id_rsa.pub`) |

## Quick Start (Local)

```bash
# 1. Clone and configure
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars with your values

# 2. Export your SSH key
export TF_VAR_deployer_public_key=$(cat ~/.ssh/id_rsa.pub)

# 3. Plan
./scripts/deploy-infrastructure.sh plan

# 4. Apply
./scripts/deploy-infrastructure.sh apply
```

## After First Apply

```bash
# View all outputs
cd terraform && terraform output

# 1. Whitelist NAT EIP IPs in MongoDB Atlas
terraform output nat_eip_public_ips

# 2. Store secrets in AWS SSM Parameter Store
aws ssm put-parameter \
  --name "/starttech/prod/MONGO_URI" \
  --value "mongodb+srv://user:pass@cluster.mongodb.net/much_todo_db" \
  --type SecureString \
  --region us-east-1

aws ssm put-parameter \
  --name "/starttech/prod/JWT_SECRET_KEY" \
  --value "$(openssl rand -hex 32)" \
  --type SecureString \
  --region us-east-1

# 3. Set GitHub Secrets in starttech-application repo:
#    S3_BUCKET_NAME          = $(terraform output -raw s3_bucket_name)
#    CLOUDFRONT_DISTRIBUTION_ID = $(terraform output -raw cloudfront_distribution_id)
#    ECR_REPOSITORY_NAME     = $(terraform output -raw ecr_repository_name)
#    AWS_ACCOUNT_ID          = $(aws sts get-caller-identity --query Account --output text)
#    ALB_DNS_NAME            = $(terraform output -raw alb_dns_name)
#    VITE_API_BASE_URL       = http://$(terraform output -raw alb_dns_name)
```

## CI/CD Pipeline

| Trigger | Action |
|---|---|
| PR targeting `main` with changes to `terraform/**` | `terraform plan` posted as PR comment |
| Push to `main` with changes to `terraform/**` | `terraform apply` (requires `production` environment approval) |

## Destroying Infrastructure

```bash
./scripts/deploy-infrastructure.sh destroy
```
