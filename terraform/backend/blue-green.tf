# terraform/backend/blue-green.tf
# AWS Professional Blue/Green Deployment (CodeDeploy + ECS)

# --- CodeDeploy Service Role ---
resource "aws_iam_role" "codedeploy_service_role" {
  name = "${var.project_name}-codedeploy-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy_service_role_policy" {
  role       = aws_iam_role.codedeploy_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

# --- CodeDeploy Application ---
resource "aws_codedeploy_app" "ecs_app" {
  name             = "${var.project_name}-ecs-app"
  compute_platform = "ECS"
}

# --- CodeDeploy Deployment Group ---
resource "aws_codedeploy_deployment_group" "ecs_deployment_group" {
  app_name              = aws_codedeploy_app.ecs_app.name
  deployment_group_name = "${var.project_name}-deployment-group"
  service_role_arn      = aws_iam_role.codedeploy_service_role.arn

  # 【修正点 1: デプロイ設定の変更】
  # 元々カナリアデプロイ (CodeDeployDefault.ECSCanary10Percent5Minutes) が設定されていましたが、
  # Blue/Greenデプロイメントのベストプラクティスとして、トラフィックを一度に切り替える
  # ECSAllAtOnce に変更しました。これによりBlue/Greenの意図に沿った動作になります。
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  blue_green_deployment_config {
    deployment_ready_option {
      # 【修正点 2: タイムアウト時の動作変更】
      # 元々 CONTINUE_DEPLOYMENT でタイムアウトしてもデプロイを続行する設定でしたが、
      # 問題発生時にデプロイを停止し、安全性を確保するため STOP_DEPLOYMENT に変更しました。
      action_on_timeout = "STOP_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                         = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.main.name
    service_name = aws_ecs_service.blue.name
  }

  # AWS Professional設計: ECS Blue/Greenではload_balancer_info不要
  # ターゲットグループ情報はECSサービスから自動継承

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }

  alarm_configuration {
    enabled = true
    # 【修正点 3: アラーム設定の最適化】
    # ロールバックトリガーとして設定するアラームは、新しくデプロイされる
    # Green環境の健全性を監視するものが適切です。
    # 元々含まれていたBlue環境用のアラームは不要であるため、Green環境用のみに限定しました。
    alarms = [
      aws_cloudwatch_metric_alarm.deployment_health_green.alarm_name
    ]
  }
}

# --- Professional Health Check Alarm (Blue) ---
resource "aws_cloudwatch_metric_alarm" "deployment_health" {
  alarm_name          = "${var.project_name}-deployment-health"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "Professional deployment health monitoring - Blue environment"

  dimensions = {
    TargetGroup  = aws_lb_target_group.blue.arn_suffix
    LoadBalancer = aws_lb.main.arn_suffix
  }
}

# --- Professional Health Check Alarm (Green) ---
resource "aws_cloudwatch_metric_alarm" "deployment_health_green" {
  alarm_name          = "${var.project_name}-deployment-health-green"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "Professional deployment health monitoring - Green environment"

  dimensions = {
    TargetGroup  = aws_lb_target_group.green.arn_suffix
    LoadBalancer = aws_lb.main.arn_suffix
  }
}
