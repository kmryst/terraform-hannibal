# terraform/backend/codedeploy.tf
# AWS Official CodeDeploy Blue/Green for ECS Implementation
# Compliant with AWS Documentation and Best Practices

# --- CodeDeploy Application ---
resource "aws_codedeploy_app" "ecs_app" {
  compute_platform = "ECS"
  name             = "${var.project_name}-codedeploy-app"
  
  tags = {
    Name        = "${var.project_name} CodeDeploy Application"
    project     = var.project_name
    environment = var.environment
  }
}

# --- CodeDeploy Deployment Group ---
resource "aws_codedeploy_deployment_group" "ecs_deployment_group" {
  app_name               = aws_codedeploy_app.ecs_app.name
  deployment_group_name  = "${var.project_name}-deployment-group"
  service_role_arn       = aws_iam_role.codedeploy_service_role.arn
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

  # Blue/Green Deployment Style (Required)
  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  # ECS Service Configuration (Required)
  ecs_service {
    cluster_name = aws_ecs_cluster.main.name
    service_name = aws_ecs_service.api.name
  }

  # Load Balancer Configuration (Required for ECS Blue/Green)
  load_balancer_info {
    target_group_pair_info {
      # Production Traffic Route (Port 80)
      prod_traffic_route {
        listener_arns = [aws_lb_listener.http.arn]
      }
      
      # Test Traffic Route (Port 8080)
      test_traffic_route {
        listener_arns = [aws_lb_listener.test.arn]
      }
      
      # Blue/Green Target Groups
      target_group {
        name = aws_lb_target_group.blue.name
      }
      
      target_group {
        name = aws_lb_target_group.green.name
      }
    }
  }

  # Blue/Green Deployment Configuration (Required for ECS)
  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout    = "STOP_DEPLOYMENT"
      wait_time_in_minutes = 1
    }
    
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 1
    }
  }

  # Auto Rollback Configuration
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
  
  tags = {
    Name        = "${var.project_name} Deployment Group"
    project     = var.project_name
    environment = var.environment
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

# --- IAM Policy Attachment (AWS Managed Policy) ---
resource "aws_iam_role_policy_attachment" "codedeploy_service_role_policy" {
  role       = aws_iam_role.codedeploy_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

# --- Additional IAM Policy for PassRole (Required for ECS Task Execution Role) ---
resource "aws_iam_role_policy" "codedeploy_passrole_policy" {
  name = "${var.project_name}-codedeploy-passrole-policy"
  role = aws_iam_role.codedeploy_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.ecs_task_execution_role.arn
        ]
      }
    ]
  })
}

# --- CloudWatch Log Group for CodeDeploy ---
resource "aws_cloudwatch_log_group" "codedeploy_logs" {
  name              = "/aws/codedeploy/${var.project_name}"
  retention_in_days = local.enable_backup ? 30 : 7
  
  tags = {
    Name        = "${var.project_name} CodeDeploy Logs"
    project     = var.project_name
    environment = var.environment
  }
}