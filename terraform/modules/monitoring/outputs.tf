output "log_group_backend_app_name" {
  description = "Name of the backend application CloudWatch log group"
  value       = aws_cloudwatch_log_group.backend_app.name
}

output "log_group_backend_access_name" {
  description = "Name of the backend access CloudWatch log group"
  value       = aws_cloudwatch_log_group.backend_access.name
}

output "sns_topic_arn" {
  description = "ARN of the SNS alerts topic"
  value       = aws_sns_topic.alerts.arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}
