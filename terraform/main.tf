terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket  = "starttech-terraform-state-026138522504"
    key     = "prod/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.region
}

module "networking" {
  source = "./modules/networking"

  title  = var.title
  region = var.region
}

module "storage" {
  source = "./modules/storage"

  title              = var.title
  region             = var.region
  private_subnet_ids = module.networking.private_subnet_ids
  cache_sg_id        = module.networking.cache_sg_id
  redis_node_type    = var.redis_node_type
}

module "compute" {
  source = "./modules/compute"

  title               = var.title
  region              = var.region
  vpc_id              = module.networking.vpc_id
  web_sg_id           = module.networking.web_sg_id
  lb_sg_id            = module.networking.lb_sg_id
  public_subnet_ids   = module.networking.public_subnet_ids
  private_subnet_ids  = module.networking.private_subnet_ids
  instance_type       = var.instance_type
  key_pair_name       = var.key_pair_name
  deployer_public_key = var.deployer_public_key
  ecr_repository_name = var.ecr_repository_name
  asg_min_size        = var.asg_min_size
  asg_max_size        = var.asg_max_size
  asg_desired_capacity = var.asg_desired_capacity
  cloudfront_domain   = module.storage.cloudfront_domain_name

  depends_on = [module.networking, module.storage]
}

module "monitoring" {
  source = "./modules/monitoring"

  title                   = var.title
  region                  = var.region
  asg_name                = module.compute.asg_name
  alb_arn_suffix          = module.compute.alb_arn_suffix
  target_group_arn_suffix = module.compute.target_group_arn_suffix
  scale_out_policy_arn    = module.compute.scale_out_policy_arn
  alert_email             = var.alert_email

  depends_on = [module.compute]
}

# Store CloudFront domain in SSM so EC2 user-data can set ALLOWED_ORIGINS
resource "aws_ssm_parameter" "cloudfront_domain" {
  name  = "/starttech/prod/CLOUDFRONT_DOMAIN"
  type  = "String"
  value = module.storage.cloudfront_domain_name

  tags = {
    Name = "${var.title}-cloudfront-domain-param"
  }
}

# Store ECR repository name in SSM for EC2 user-data
resource "aws_ssm_parameter" "ecr_repository_name" {
  name  = "/starttech/prod/ECR_REPOSITORY_NAME"
  type  = "String"
  value = module.compute.ecr_repository_name

  tags = {
    Name = "${var.title}-ecr-repo-name-param"
  }
} 