output "codedeploy_application_name" {
  description = "CodeDeploy application name"
  value       = module.codedeploy.codedeploy_app_name
}

output "codedeploy_deployment_group_name" {
  description = "CodeDeploy deployment group name"
  value       = module.codedeploy.codedeploy_deployment_group_name
}

output "codedeploy_s3_bucket" {
  description = "S3 bucket for CodeDeploy artifacts"
  value       = module.codedeploy.s3_bucket_name
}

output "blue_target_group_name" {
  description = "Blue target group name"
  value       = module.load_balancer.blue_target_group_name
}

output "green_target_group_name" {
  description = "Green target group name"
  value       = module.load_balancer.green_target_group_name
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.load_balancer.alb_dns_name
}

output "alb_zone_id" {
  description = "ALB hosted zone ID"
  value       = module.load_balancer.alb_zone_id
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.ecs.service_name
}

output "dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = module.monitoring.dashboard_url
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alarm notifications"
  value       = module.monitoring.sns_topic_arn
}

output "alb_origin_verify_header_value" {
  description = "ALB origin verify header value for CloudFront"
  value       = random_password.alb_origin_verify_header.result
  sensitive   = true
}

output "slo_error_rate_fast_burn_alarm_arn" {
  description = "ARN of the SLO error-rate fast-burn alarm (consumed by terraform/observability as an AWS FIS stop condition, Issue #458)"
  value       = module.monitoring.slo_error_rate_fast_burn_alarm_arn
}
