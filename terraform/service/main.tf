data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "nestjs-hannibal-3-terraform-state"
    key    = "network/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

data "terraform_remote_state" "database" {
  backend = "s3"

  config = {
    bucket = "nestjs-hannibal-3-terraform-state"
    key    = "database/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

locals {
  alb_origin_verify_header_name = "X-Hannibal-Origin-Verify"
}

resource "random_password" "alb_origin_verify_header" {
  length  = 32
  special = false

  keepers = {
    version = var.alb_origin_secret_rotation_version
  }
}

module "load_balancer" {
  source = "../modules/load-balancer"

  project_name                   = var.project_name
  environment                    = var.environment
  vpc_id                         = data.terraform_remote_state.network.outputs.vpc_id
  alb_security_group_id          = data.terraform_remote_state.network.outputs.alb_security_group_id
  public_subnet_ids              = data.terraform_remote_state.network.outputs.public_subnet_ids
  container_port                 = var.container_port
  health_check_path              = var.health_check_path
  alb_certificate_arn            = var.alb_certificate_arn
  alb_origin_verify_header_name  = local.alb_origin_verify_header_name
  alb_origin_verify_header_value = random_password.alb_origin_verify_header.result
}

module "ecs" {
  source = "../modules/ecs"

  project_name                = var.project_name
  aws_region                  = var.aws_region
  ecr_repository_url          = var.ecr_repository_url
  container_port              = var.container_port
  desired_task_count          = var.desired_task_count
  cpu                         = var.cpu
  memory                      = var.memory
  client_url_for_cors         = var.client_url_for_cors
  db_name                     = var.db_name
  db_credentials_secret_arn   = data.terraform_remote_state.database.outputs.master_user_secret_arn
  app_subnet_ids              = data.terraform_remote_state.network.outputs.app_subnet_ids
  ecs_security_group_id       = data.terraform_remote_state.network.outputs.ecs_security_group_id
  blue_target_group_arn       = module.load_balancer.blue_target_group_arn
  alb_listener_production_arn = module.load_balancer.https_listener_arn
  alb_listener_test_arn       = module.load_balancer.test_listener_arn
  rds_endpoint                = data.terraform_remote_state.database.outputs.db_instance_endpoint
}

module "monitoring" {
  source = "../modules/monitoring"

  project_name     = var.project_name
  aws_region       = var.aws_region
  alert_email      = var.alert_email
  ecs_service_name = module.ecs.service_name
  ecs_cluster_name = module.ecs.cluster_name
  rds_instance_id  = data.terraform_remote_state.database.outputs.db_instance_id
  alb_arn_suffix   = module.load_balancer.alb_arn

  # Synthetics canaryのtime-based availability SLI(ADR-0030, Issue #467)。
  # enable_synthetics_canary=falseの場合は空文字を渡し、monitoringモジュール側でアラーム自体を作成しない。
  synthetics_canary_name = var.enable_synthetics_canary ? module.synthetics_canary[0].canary_name : ""
}

# Synthetics canaryはCloudFront経由でアクセスするため、origin-verifyヘッダー用の
# Secrets Manager secretとcanaryへの受け渡しは不要(Issue #481、ADR-0030「更新」節参照)。
# ALB直接アクセス防止はCloudFront custom_header + load-balancerのdenyルールで完結する。
module "synthetics_canary" {
  count  = var.enable_synthetics_canary ? 1 : 0
  source = "../modules/synthetics"

  project_name        = var.project_name
  aws_region          = var.aws_region
  canary_name         = var.synthetics_canary_name
  schedule_expression = var.synthetics_schedule_expression

  frontend_url    = "https://${var.domain_name}/"
  api_health_url  = "https://${var.domain_name}${var.health_check_path}"
  api_graphql_url = "https://${var.domain_name}/graphql"
  graphql_query   = var.synthetics_graphql_query

  tags = {
    Environment = var.environment
  }
}

module "codedeploy" {
  source = "../modules/codedeploy"

  project_name                    = var.project_name
  environment                     = var.environment
  deployment_type                 = var.deployment_type
  blue_target_group_name          = module.load_balancer.blue_target_group_name
  green_target_group_name         = module.load_balancer.green_target_group_name
  ecs_cluster_name                = module.ecs.cluster_name
  ecs_service_name                = module.ecs.service_name
  alb_listener_production_arn     = module.load_balancer.https_listener_arn
  alb_listener_test_arn           = module.load_balancer.test_listener_arn
  canary_error_rate_alarm_name    = module.monitoring.canary_error_rate_alarm_name
  canary_response_time_alarm_name = module.monitoring.canary_response_time_alarm_name
}
