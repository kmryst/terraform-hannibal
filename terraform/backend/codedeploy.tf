# terraform/backend/codedeploy.tf
# AWS Professional CodeDeploy Blue/Green for ECS
# Based on Netflix/Airbnb/Spotify enterprise patterns

# --- Data Sources ---
data "aws_caller_identity" "current" {}

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

  # 企業レベル自動ロールバック設定
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }

  # Blue/Green デプロイメント設定
  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  # ECS サービス設定
  ecs_service {
    cluster_name = aws_ecs_cluster.main.name
    service_name = aws_ecs_service.api.name
  }


  
  # Blue/Green設定（必須）
  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout    = "STOP_DEPLOYMENT"
      wait_time_in_minutes = 1
    }
    
    green_fleet_provisioning_option {
      action = "COPY_AUTO_SCALING_GROUP"
    }
    
    terminate_blue_instances_on_deployment_success {
      action = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }
  
  # ロードバランサー設定（Target Group Pair Info）
  load_balancer_info {
    target_group_pair_info {
      # 本番トラフィック用リスナー（ポート80）
      prod_traffic_route {
        listener_arns = [aws_lb_listener.http.arn]
      }
      
      # テストトラフィック用リスナー（ポート8080）
      test_traffic_route {
        listener_arns = [aws_lb_listener.test.arn]
      }
      
      # Blue/Green ターゲットグループ
      target_group {
        name = aws_lb_target_group.blue.name
      }
      
      target_group {
        name = aws_lb_target_group.green.name
      }
    }
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

# --- IAM Policy Attachments for CodeDeploy ---
resource "aws_iam_role_policy_attachment" "codedeploy_service_role_policy" {
  role       = aws_iam_role.codedeploy_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

# IAM inline policy removed due to Permission Boundary restrictions
# Enhanced permissions should be added to foundation IAM policies



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

