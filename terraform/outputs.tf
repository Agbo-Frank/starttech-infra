output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer (use as VITE_API_BASE_URL in frontend build)"
  value       = module.compute.alb_dns_name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for frontend hosting (set as S3_BUCKET_NAME GitHub secret)"
  value       = module.storage.s3_bucket_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (set as CLOUDFRONT_DISTRIBUTION_ID GitHub secret)"
  value       = module.storage.cloudfront_distribution_id
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name (access the frontend here)"
  value       = "https://${module.storage.cloudfront_domain_name}"
}

output "ecr_repository_url" {
  description = "ECR repository URL for pushing backend Docker images"
  value       = module.compute.ecr_repository_url
}

output "ecr_repository_name" {
  description = "ECR repository name (set as ECR_REPOSITORY_NAME GitHub secret)"
  value       = module.compute.ecr_repository_name
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.compute.asg_name
}

output "nat_eip_public_ips" {
  description = "Public IPs of NAT gateways – add these to MongoDB Atlas IP Access List"
  value       = module.networking.nat_eip_public_ips
}

output "redis_primary_endpoint" {
  description = "ElastiCache Redis primary endpoint (already stored in SSM /starttech/prod/REDIS_ADDR)"
  value       = module.storage.redis_primary_endpoint
}

output "cloudwatch_dashboard" {
  description = "CloudWatch dashboard name"
  value       = module.monitoring.dashboard_name
}
