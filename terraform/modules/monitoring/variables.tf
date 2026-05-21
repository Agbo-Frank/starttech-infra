variable "title" {
  description = "Name prefix applied to all resource tags"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "asg_name" {
  description = "Name of the Auto Scaling Group to monitor"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the ALB (for CloudWatch metrics)"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "ARN suffix of the target group (for CloudWatch metrics)"
  type        = string
}

variable "scale_out_policy_arn" {
  description = "ARN of the ASG scale-out policy"
  type        = string
}

variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications (optional)"
  type        = string
  default     = ""
}
