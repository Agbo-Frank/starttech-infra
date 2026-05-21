variable "title" {
  description = "Name prefix applied to all resource tags"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "web_sg_id" {
  description = "ID of the web/backend security group"
  type        = string
}

variable "lb_sg_id" {
  description = "ID of the load balancer security group"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs (for ALB)"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs (for EC2 instances)"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type for backend instances"
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "Name of the EC2 key pair"
  type        = string
}

variable "deployer_public_key" {
  description = "Public SSH key content for the EC2 key pair"
  type        = string
  sensitive   = true
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository for backend Docker images"
  type        = string
  default     = "starttech-backend"
}

variable "asg_min_size" {
  description = "Minimum number of instances in the ASG"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of instances in the ASG"
  type        = number
  default     = 3
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in the ASG"
  type        = number
  default     = 2
}

variable "cloudfront_domain" {
  description = "CloudFront domain to allow in CORS (set after storage module is applied)"
  type        = string
  default     = ""
}
