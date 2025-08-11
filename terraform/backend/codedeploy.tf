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

  # 企業レベル通知設定
  trigger_configuration {
    trigger_events = [
      "DeploymentStart",
      "DeploymentSuccess", 
      "DeploymentFailure",
      "DeploymentStop",
      "DeploymentRollback"
    ]
    trigger_name       = "${var.project_name}-deployment-trigger"
    trigger_target_arn = aws_sns_topic.deployment_notifications.arn
  }
  
  # CloudWatch アラーム設定（企業レベル監視）
  alarm_configuration {
    enabled = true
    alarms  = [aws_cloudwatch_metric_alarm.ecs_green_health_check_failed.alarm_name]
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

# --- Custom IAM Policy for Enhanced CodeDeploy Permissions ---
resource "aws_iam_role_policy" "codedeploy_enhanced_policy" {
  name = "${var.project_name}-codedeploy-enhanced-policy"
  role = aws_iam_role.codedeploy_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:CreateTaskSet",
          "ecs:UpdateServicePrimaryTaskSet",
          "ecs:DeleteTaskSet",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:ModifyRule",
          "cloudwatch:DescribeAlarms",
          "sns:Publish"
        ]
        Resource = "*"
      }
    ]
  })
}

# --- SNS Topic for Deployment Notifications ---
resource "aws_sns_topic" "deployment_notifications" {
  name              = "${var.project_name}-alerts"
  kms_master_key_id = "alias/aws/sns"
  
  tags = {
    Name        = "${var.project_name} Deployment Notifications"
    project     = var.project_name
    environment = var.environment
  }
}

# --- CloudWatch Metric Alarm for ECS Service Health ---
resource "aws_cloudwatch_metric_alarm" "ecs_green_health_check_failed" {
  alarm_name          = "ecs-green-health-check-failed"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "This metric monitors ECS green environment health"
  alarm_actions       = [aws_sns_topic.deployment_notifications.arn]
  
  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.api.name
  }
  
  tags = {
    Name        = "ECS Green Health Check Failed Alarm"
    project     = var.project_name
    environment = var.environment
  }
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

