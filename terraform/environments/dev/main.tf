# terraform/environments/dev/main.tf
# AWS Well-Architected準拠 - 開発環境統合設定

# --- AWS Professional Environment Configuration ---
locals {
  # 環境別リソース最適化（Netflix/Airbnb/Spotify標準パターン）
  enable_multi_az        = var.environment != "dev"
  enable_backup          = var.environment != "dev"
  backup_retention_days  = var.environment == "prod" ? 7 : 0
  publicly_accessible    = var.environment == "dev"
  deletion_protection    = var.environment == "prod"
}

# --- Security Pillar: セキュリティグループ ---
module "security_groups" {
  source = "../../modules/security/security-groups"
  
  vpc_id         = module.vpc.vpc_id
  project_name   = var.project_name
  environment    = var.environment
  container_port = var.container_port
}

# --- Security Pillar: IAM ---
module "iam" {
  source = "../../modules/security/iam"
  
  project_name = var.project_name
}

# --- Reliability + Performance Pillar: VPC ---
module "vpc" {
  source = "../../modules/networking/vpc"
  
  project_name = var.project_name
  environment  = var.environment
}

# --- Reliability Pillar: DNS ---
module "dns" {
  source = "../../modules/networking/dns"
}

# --- Performance + Cost Optimization Pillar: CodeDeploy ---
module "codedeploy" {
  source = "../../modules/cicd/codedeploy"
  
  project_name                     = var.project_name
  environment                      = var.environment
  vpc_id                          = module.vpc.vpc_id
  container_port                  = var.container_port
  health_check_path               = var.health_check_path
  deployment_type                 = var.deployment_type
  ecs_cluster_name                = module.ecs.cluster_name
  ecs_service_name                = module.ecs.service_name
  alb_listener_http_arn           = module.load_balancer.http_listener_arn
  alb_listener_test_arn           = module.load_balancer.test_listener_arn
  canary_error_rate_alarm_name    = module.monitoring.canary_error_rate_alarm_name
  canary_response_time_alarm_name = module.monitoring.canary_response_time_alarm_name
}

# --- Performance + Cost Optimization Pillar: Load Balancer ---
module "load_balancer" {
  source = "../../modules/compute/load-balancer"
  
  project_name           = var.project_name
  alb_security_group_id  = module.security_groups.alb_security_group_id
  public_subnet_ids      = module.vpc.public_subnet_ids
  alb_listener_port      = var.alb_listener_port
  blue_target_group_arn  = module.codedeploy.blue_target_group_arn
  green_target_group_arn = module.codedeploy.green_target_group_arn
}

# --- Performance + Cost Optimization Pillar: ECS ---
module "ecs" {
  source = "../../modules/compute/ecs"
  
  project_name                 = var.project_name
  environment                  = var.environment
  aws_region                   = var.aws_region
  ecr_repository_url           = var.ecr_repository_url
  container_port               = var.container_port
  desired_task_count           = var.desired_task_count
  cpu                          = var.cpu
  memory                       = var.memory
  client_url_for_cors          = var.client_url_for_cors
  db_username                  = var.db_username
  db_password                  = var.db_password
  db_name                      = var.db_name
  ecs_task_execution_role_arn  = module.iam.ecs_task_execution_role_arn
  app_subnet_ids               = module.vpc.app_subnet_ids
  ecs_security_group_id        = module.security_groups.ecs_security_group_id
  blue_target_group_arn        = module.codedeploy.blue_target_group_arn
  alb_listener_http_arn        = module.load_balancer.http_listener_arn
  alb_listener_test_arn        = module.load_balancer.test_listener_arn
  rds_endpoint                 = module.rds.db_instance_endpoint
}

# --- Reliability + Cost Optimization Pillar: RDS ---
module "rds" {
  source = "../../modules/storage/rds"
  
  project_name           = var.project_name
  environment            = var.environment
  data_subnet_ids        = module.vpc.data_subnet_ids
  rds_security_group_id  = module.security_groups.rds_security_group_id
  db_instance_class      = var.db_instance_class
  db_allocated_storage   = var.db_allocated_storage
  db_engine_version      = var.db_engine_version
  db_name                = var.db_name
  db_username            = var.db_username
  db_password            = var.db_password
}

# --- Operational Excellence Pillar: Monitoring ---
module "monitoring" {
  source = "../../modules/observability/monitoring"
  
  project_name      = var.project_name
  aws_region        = var.aws_region
  alert_email       = var.alert_email
  ecs_service_name  = module.ecs.service_name
  ecs_cluster_name  = module.ecs.cluster_name
  rds_instance_id   = module.rds.db_instance_id
  alb_arn_suffix    = module.load_balancer.alb_arn
}