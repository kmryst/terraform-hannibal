output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "canary_error_rate_alarm_name" {
  description = "Name of the canary error rate alarm"
  value       = aws_cloudwatch_metric_alarm.canary_error_rate.alarm_name
}

output "canary_response_time_alarm_name" {
  description = "Name of the canary response time alarm"
  value       = aws_cloudwatch_metric_alarm.canary_response_time.alarm_name
}

output "dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}