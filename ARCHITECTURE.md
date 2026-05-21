# Architecture

## Network Topology

```
                        ┌─────────────────────────────────────────────┐
                        │              AWS VPC (10.0.0.0/16)           │
                        │                                              │
 Internet ──────────────┤  Public Subnets (10.0.1.0/24, 10.0.2.0/24) │
                        │  ┌──────────┐  ┌──────────┐                │
                        │  │  NAT GW  │  │  NAT GW  │                │
                        │  │  (AZ-1)  │  │  (AZ-2)  │                │
                        │  └──────────┘  └──────────┘                │
                        │       │               │                     │
                        │  ┌─────────────────────────┐               │
                        │  │   Application Load Balancer│              │
                        │  │      (port 80/443)        │              │
                        │  └─────────────────────────┘               │
                        │              │                               │
                        │  Private Subnets (10.0.3.0/24, 10.0.4.0/24)│
                        │  ┌──────────┐  ┌──────────┐                │
                        │  │  EC2 #1  │  │  EC2 #2  │  ← ASG        │
                        │  │ (port    │  │ (port    │                │
                        │  │  8080)   │  │  8080)   │                │
                        │  └────┬─────┘  └────┬─────┘               │
                        │       │              │                       │
                        │  ┌────▼──────────────▼────┐                │
                        │  │  ElastiCache Redis 7.x  │                │
                        │  │     (port 6379)          │               │
                        │  └─────────────────────────┘               │
                        └─────────────────────────────────────────────┘
                                          │
                                  MongoDB Atlas
                                  (external, TLS)
```

## Traffic Flows

### Frontend (React SPA)
```
Browser → CloudFront (HTTPS) → S3 bucket (private)
```
- CloudFront uses Origin Access Control (OAC) — S3 is not publicly accessible
- `index.html` is served with `no-cache` headers so browsers always fetch the latest SPA entry point
- Static assets (JS/CSS with content hashes) are served with `max-age=31536000,immutable`
- All 403/404 errors return `index.html` (HTTP 200) to support client-side routing

### Backend API
```
Browser → CloudFront (API call fails — not proxied)
Browser → ALB HTTP:80 → EC2:8080 (Go app, Docker container)
```
- ALB health check: `GET /ping` → expects `200 OK` with `{"message":"pong"}`
- EC2 instances use SSM Session Manager for shell access (no SSH port open)
- All outbound traffic (to Atlas, to ECR) routes through NAT Gateways

## Security Groups

| Group | Inbound | Outbound |
|---|---|---|
| `lb-sg` | 80/443 from `0.0.0.0/0` | All |
| `web-sg` | 8080 from `lb-sg` only | All |
| `cache-sg` | 6379 from `web-sg` only | All |

## IAM Trust Boundaries

```
EC2 Instance Role (starttech-ec2-role)
├── Managed: AmazonSSMManagedInstanceCore   (SSM Session Manager)
└── Inline policy:
    ├── ECR: GetAuthorizationToken, BatchGetImage, GetDownloadUrlForLayer
    ├── SSM: GetParameter/GetParameters  (scoped to /starttech/prod/*)
    └── CloudWatch Logs: CreateLogGroup, CreateLogStream, PutLogEvents
                         (scoped to /starttech/* log groups)
```

## Secret Management Flow

```
Secrets at rest:
  /starttech/prod/MONGO_URI        (SSM SecureString — manually set)
  /starttech/prod/JWT_SECRET_KEY   (SSM SecureString — manually set)
  /starttech/prod/REDIS_ADDR       (SSM String — set by Terraform storage module)
  /starttech/prod/CLOUDFRONT_DOMAIN (SSM String — set by Terraform root)
  /starttech/prod/ECR_REPOSITORY_NAME (SSM String — set by Terraform root)

EC2 boot:
  user-data script → aws ssm get-parameter → docker run -e ...

CI/CD:
  GitHub Secrets → GitHub Actions env → ECR push, S3 sync, CloudFront invalidation
```

## Deployment Strategies

### Backend: ASG Instance Refresh (Rolling)
1. Pipeline pushes new Docker image to ECR as `:<git-sha>` and `:latest`
2. Pipeline calls `aws autoscaling start-instance-refresh`
3. ASG terminates old instances gradually (min 50% healthy)
4. New instances launch from the latest Launch Template, run user-data script, pull `:latest` from ECR
5. Pipeline polls refresh status until `Successful`, then runs `/ping` smoke test

### Frontend: S3 Sync + CloudFront Invalidation
1. Pipeline builds Vite bundle (with `VITE_API_BASE_URL` baked in)
2. Static assets (hashed filenames) synced to S3 with immutable cache headers
3. `index.html` uploaded separately with `no-cache` headers
4. CloudFront invalidation `/*` created and waited on

## Module Dependencies

```
networking → storage → compute → monitoring
                ↑
           (cache_sg_id, private_subnet_ids)
```
Root `main.tf` wires module outputs to inputs in the order above.
