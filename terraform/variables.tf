variable "region" {
  description = "AWS region to deploy all resources"
  type        = string
  default     = "us-east-1"
}

variable "title" {
  description = "Name prefix applied to all resources for identification"
  type        = string
  default     = "starttech"
}

variable "instance_type" {
  description = "EC2 instance type for backend ASG instances"
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "Name of the EC2 SSH key pair to create"
  type        = string
  default     = "starttech-deployer"
}

variable "deployer_public_key" {
  description = "Public SSH key content for EC2 instance access"
  type        = string
  sensitive   = true
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository for backend Docker images"
  type        = string
  default     = "starttech-backend"
}

variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "asg_min_size" {
  description = "Minimum number of EC2 instances in the Auto Scaling Group"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of EC2 instances in the Auto Scaling Group"
  type        = number
  default     = 3
}

variable "asg_desired_capacity" {
  description = "Desired number of EC2 instances in the Auto Scaling Group"
  type        = number
  default     = 2
}

variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications (leave empty to skip)"
  type        = string
  default     = ""
}
