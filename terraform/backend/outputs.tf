# terraform/backend/outputs.tf
/**
 * Terraform アウトプット定義ファイル
 * 
 * ハンニバルのアルプス越えルートアプリケーションの
 * インフラストラクチャ情報を外部に公開するためのアウトプット定義。
 * 
 * 主要用途:
 * - CI/CD パイプラインでのリソース情報参照
 * - 他の Terraform モジュールとの連携
 * - アプリケーション設定でのエンドポイント情報取得
 * - 監視・デバッグ用のリソース識別子
 */

# --- CodeDeploy Blue/Green デプロイメント関連 ---
# CodeDeploy アプリケーション名: GitHub Actions でのデプロイメント実行時に使用
output "codedeploy_application_name" {
  description = "CodeDeploy application name for Blue/Green deployment"
  value       = aws_codedeploy_app.main.name
}

output "codedeploy_deployment_group_name" {
  description = "CodeDeploy deployment group name"
  value       = aws_codedeploy_deployment_group.main.deployment_group_name
}

output "codedeploy_s3_bucket" {
  description = "CodeDeploy S3 bucket name"
  value       = aws_s3_bucket.codedeploy_artifacts.bucket
}

output "codedeploy_deployment_config_name" {
  description = "CodeDeploy deployment config name"
  value       = "CodeDeployDefault.ECSAllAtOnce"
}

# --- CodeDeploy Blue/Green Configuration Outputs ---
output "production_listener_arn" {
  description = "Production listener ARN (Port 80)"
  value       = aws_lb_listener.http.arn
}

output "test_listener_arn" {
  description = "Test listener ARN (Port 8080)"
  value       = aws_lb_listener.test.arn
}

output "blue_target_group_name" {
  description = "Blue target group name"
  value       = aws_lb_target_group.blue.name
}

output "green_target_group_name" {
  description = "Green target group name"
  value       = aws_lb_target_group.green.name
}

output "codedeploy_wait_time_minutes" {
  description = "CodeDeploy wait time in minutes"
  value       = 1
}

output "codedeploy_termination_wait_time_minutes" {
  description = "CodeDeploy termination wait time in minutes"
  value       = 1
}

output "codedeploy_service_role_arn" {
  description = "CodeDeploy service role ARN"
  value       = aws_iam_role.codedeploy_service_role.arn
}

# --- Blue/Green Target Groups ---
output "blue_target_group_arn" {
  description = "Blue target group ARN"
  value       = aws_lb_target_group.blue.arn
}

output "green_target_group_arn" {
  description = "Green target group ARN"
  value       = aws_lb_target_group.green.arn
}

# --- ALB Listeners ---


# --- Application Load Balancer (ALB) 情報 ---
# ALB DNS名: フロントエンドからの API アクセス用エンドポイント
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer for API access"
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

# --- Amazon ECS (Elastic Container Service) 情報 ---
# ECS クラスター名: コンテナアプリケーションの実行環境識別子
output "ecs_cluster_name" {
  description = "Name of the ECS cluster running the Hannibal application"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.api.name
}

output "ecs_task_sg_id" {
  description = "ECS Task Security Group ID"
  value       = aws_security_group.ecs.id
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = var.ecr_repository_url
}

# --- Amazon RDS PostgreSQL データベース情報 ---
# RDS エンドポイント: アプリケーションからのデータベース接続用
output "db_endpoint" {
  description = "RDS PostgreSQL endpoint for application database connection"
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

# --- Amazon VPC (Virtual Private Cloud) ネットワーク情報 ---
# VPC ID: 3層アーキテクチャのメインネットワーク識別子
output "vpc_id" {
  description = "VPC ID for the three-tier architecture network"
  value       = aws_vpc.main.id
}

# --- Subnet IDs ---
output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = { for k, v in aws_subnet.public : k => v.id }
}

output "app_subnet_ids" {
  description = "App subnet IDs"
  value       = { for k, v in aws_subnet.app : k => v.id }
}

output "data_subnet_ids" {
  description = "Data subnet IDs"
  value       = { for k, v in aws_subnet.data : k => v.id }
}

# --- Route Table IDs ---
output "public_route_table_id" {
  description = "Public route table ID"
  value       = aws_route_table.public.id
}

output "app_route_table_ids" {
  description = "App route table IDs"
  value       = { for k, v in aws_route_table.app : k => v.id }
}

output "data_route_table_id" {
  description = "Data route table ID"
  value       = aws_route_table.data.id
}



# --- Monitoring ---
output "dashboard_url" {
  description = "CloudWatch Dashboard URL"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "sns_topic_arn" {
  description = "SNS Topic ARN for alerts"
  value       = aws_sns_topic.alerts.arn
}

