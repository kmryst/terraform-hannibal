# terraform/environments/dev/outputs.tf
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
output "codedeploy_application_name" {
  description = "CodeDeploy application name for Blue/Green deployment"
  value       = module.codedeploy.codedeploy_app_name
}

output "codedeploy_deployment_group_name" {
  description = "CodeDeploy deployment group name"
  value       = module.codedeploy.codedeploy_deployment_group_name
}

output "codedeploy_s3_bucket" {
  description = "CodeDeploy S3 bucket name"
  value       = module.codedeploy.s3_bucket_name
}

output "blue_target_group_name" {
  description = "Blue target group name"
  value       = module.codedeploy.blue_target_group_name
}

output "green_target_group_name" {
  description = "Green target group name"
  value       = module.codedeploy.green_target_group_name
}

# --- Application Load Balancer (ALB) 情報 ---
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer for API access"
  value       = module.load_balancer.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.load_balancer.alb_zone_id
}

# --- Amazon ECS (Elastic Container Service) 情報 ---
output "ecs_cluster_name" {
  description = "Name of the ECS cluster running the Hannibal application"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.ecs.service_name
}

output "ecs_task_sg_id" {
  description = "ECS Task Security Group ID"
  value       = module.security_groups.ecs_security_group_id
}

# --- Amazon RDS PostgreSQL データベース情報 ---
output "db_endpoint" {
  description = "RDS PostgreSQL endpoint for application database connection"
  value       = module.rds.db_instance_endpoint
}

# --- Amazon VPC (Virtual Private Cloud) ネットワーク情報 ---
output "vpc_id" {
  description = "VPC ID for the three-tier architecture network"
  value       = module.vpc.vpc_id
}

# --- Monitoring ---
output "dashboard_url" {
  description = "CloudWatch Dashboard URL"
  value       = module.monitoring.dashboard_url
}

output "sns_topic_arn" {
  description = "SNS Topic ARN for alerts"
  value       = module.monitoring.sns_topic_arn
}

# --- Frontend Outputs ---
output "cloudfront_distribution_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = module.cloudfront.distribution_domain_name
}

output "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution"
  value       = module.cloudfront.distribution_arn
}

output "s3_bucket_id" {
  description = "ID of the S3 bucket for frontend"
  value       = module.s3_frontend.bucket_id
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = module.cloudfront.distribution_arn != "" ? split("/", module.cloudfront.distribution_arn)[1] : ""
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for frontend"
  value       = module.s3_frontend.bucket_id
}