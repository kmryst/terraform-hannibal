# terraform/backend/codedeploy.tf

# --- Data Sources ---
data "aws_caller_identity" "current" {}

# --- CodeDeploy Application ---
resource "aws_codedeploy_app" "ecs_app" {
  compute_platform = "ECS"
  name             = "${var.project_name}-codedeploy-app"
}

# --- CodeDeploy Deployment Group ---
resource "aws_codedeploy_deployment_group" "ecs_deployment_group" {
  app_name               = aws_codedeploy_app.ecs_app.name
  deployment_group_name  = "${var.project_name}-deployment-group"
  service_role_arn       = aws_iam_role.codedeploy_service_role.arn
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    terminate_blue_instances_on_deployment_success {
      action                         = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }

    deployment_ready_option {
      action_on_timeout = "STOP_DEPLOYMENT"
    }
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.main.name
    service_name = aws_ecs_service.api.name
  }

  load_balancer_info {
    target_group_info {
      name = aws_lb_target_group.blue.name
    }
  }

  trigger_configuration {
    trigger_events     = ["DeploymentStart", "DeploymentSuccess", "DeploymentFailure", "DeploymentStop", "DeploymentRollback"]
    trigger_name       = "${var.project_name}-deployment-trigger"
    trigger_target_arn = aws_sns_topic.deployment_notifications.arn
  }
}

# --- IAM Role for CodeDeploy Service ---
resource "aws_iam_role" "codedeploy_service_role" {
  name                 = "${var.project_name}-codedeploy-service-role"
  permissions_boundary = "arn:aws:iam::258632448142:policy/HannibalECSBoundary"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Name        = "${var.project_name} CodeDeploy Service Role"
    project     = var.project_name
    environment = var.environment
  }
}

# --- IAM Policy Attachments for CodeDeploy ---
resource "aws_iam_role_policy_attachment" "codedeploy_service_role_policy" {
  role       = aws_iam_role.codedeploy_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

# --- SNS Topic for Deployment Notifications ---
resource "aws_sns_topic" "deployment_notifications" {
  name              = "${var.project_name}-deployment-notifications"
  kms_master_key_id = "alias/aws/sns"
  
  tags = {
    Name        = "${var.project_name} Deployment Notifications"
    project     = var.project_name
    environment = var.environment
  }
}

# --- CloudWatch Log Group for CodeDeploy ---
resource "aws_cloudwatch_log_group" "codedeploy_logs" {
  name              = "/aws/codedeploy/${var.project_name}"
  retention_in_days = local.enable_backup ? 30 : 7
  kms_key_id        = "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alias/aws/logs"
  
  tags = {
    Name        = "${var.project_name} CodeDeploy Logs"
    project     = var.project_name
    environment = var.environment
  }
}