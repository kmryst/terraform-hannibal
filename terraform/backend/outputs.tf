# terraform/backend/outputs.tf

# Terraform apply後に「どのリソースがどんな値になったか」をすぐ確認できる
# 他のTerraformプロジェクトや手作業で必要な値（例：ALBのDNS名、ECSクラスタ名など）をコピペしやすい
# フロントエンドや他システムの設定で「APIのエンドポイント」などを指定する際に便利

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "alb_listener_arn" {
  description = "ARN of the ALB HTTP listener"
  value       = aws_lb_listener.http.arn
}

# --- Blue/Green Target Groups ---
output "blue_target_group_arn" {
  description = "ARN of the Blue Target Group"
  value       = aws_lb_target_group.blue.arn
}

output "green_target_group_arn" {
  description = "ARN of the Green Target Group"
  value       = aws_lb_target_group.green.arn
}

output "blue_target_group_name" {
  description = "Name of the Blue Target Group"
  value       = aws_lb_target_group.blue.name
}

output "green_target_group_name" {
  description = "Name of the Green Target Group"
  value       = aws_lb_target_group.green.name
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

# --- Blue/Green ECS Services ---
output "blue_service_name" {
  description = "Name of the Blue ECS Service"
  value       = aws_ecs_service.blue.name
}

output "green_service_name" {
  description = "Name of the Green ECS Service"
  value       = aws_ecs_service.green.name
}

output "active_environment" {
  description = "Currently active environment (blue or green)"
  value       = var.active_environment
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = var.ecr_repository_url
}

# --- Database Outputs ---
output "db_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "db_port" {
  description = "RDS PostgreSQL port"
  value       = aws_db_instance.postgres.port
}

output "database_url" {
  description = "Database connection URL"
  value       = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.postgres.endpoint}/${var.db_name}"
  sensitive   = true
}

# --- Monitoring Outputs ---
output "dashboard_url" {
  description = "CloudWatch Dashboard URL"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "sns_topic_arn" {
  description = "SNS Topic ARN for alerts"
  value       = aws_sns_topic.alerts.arn
}

# --- Blue/Green Monitoring ---
output "blue_health_alarm_name" {
  description = "Name of the Blue environment health alarm"
  value       = aws_cloudwatch_metric_alarm.blue_health_check.alarm_name
}

output "green_health_alarm_name" {
  description = "Name of the Green environment health alarm"
  value       = aws_cloudwatch_metric_alarm.green_health_check.alarm_name
}

# --- Blue/Green Deployment Info ---
output "deployment_info" {
  description = "Blue/Green deployment information"
  value = {
    active_environment    = var.active_environment
    blue_target_group    = aws_lb_target_group.blue.name
    green_target_group   = aws_lb_target_group.green.name
    blue_service         = aws_ecs_service.blue.name
    green_service        = aws_ecs_service.green.name
    alb_dns_name         = aws_lb.main.dns_name
  }
}
