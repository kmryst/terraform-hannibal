# CodeDeploy Blue/Green Deployment Resources

# --- ALB Target Group (Blue Environment) ---
resource "aws_lb_target_group" "blue" {
  name        = "${var.project_name}-blue-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name        = "${var.project_name}-blue-tg"
    Project     = var.project_name
    Environment = var.environment
  }
}

# --- ALB Target Group (Green Environment) ---
resource "aws_lb_target_group" "green" {
  name        = "${var.project_name}-green-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name        = "${var.project_name}-green-tg"
    Project     = var.project_name
    Environment = var.environment
  }
}

# GitHub Actions → appspec.yaml作成 → S3にアップロード → CodeDeployが読み取り
# artifact: デプロイに必要な成果物・ファイル群
# 語源: Art(技術) + Fact(作られたもの) = 人工物・工芸品、自然物の対義語
resource "aws_s3_bucket" "codedeploy_artifacts" {
  bucket        = "${var.project_name}-codedeploy-artifacts"
  force_destroy = true

  tags = {
    Name        = "${var.project_name}-codedeploy-artifacts"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "codedeploy_artifacts" {
  bucket = aws_s3_bucket.codedeploy_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "codedeploy_artifacts" {
  bucket = aws_s3_bucket.codedeploy_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# CodeDeploy Service Role
resource "aws_iam_role" "codedeploy_service_role" {
  name = "${var.project_name}-codedeploy-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {                          # 主体
          Service = "codedeploy.amazonaws.com" # CodeDeployサービスがassumeする主体
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-codedeploy-service-role"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "codedeploy_service_role" {
  role       = aws_iam_role.codedeploy_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

# CodeDeploy Application
resource "aws_codedeploy_app" "main" {
  compute_platform = "ECS"
  name             = "${var.project_name}-app"

  tags = {
    Name        = "${var.project_name}-app"
    Project     = var.project_name
    Environment = var.environment
  }
}

# CodeDeploy Deployment Group
resource "aws_codedeploy_deployment_group" "main" {
  app_name               = aws_codedeploy_app.main.name
  deployment_group_name  = "${var.project_name}-dg"
  service_role_arn       = aws_iam_role.codedeploy_service_role.arn
  deployment_config_name = var.deployment_type == "canary" ? "CodeDeployDefault.ECSCanary10Percent5Minutes" : "CodeDeployDefault.ECSAllAtOnce"

  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  blue_green_deployment_config {
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 1
    }

    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
  }

  ecs_service {
    cluster_name = var.ecs_cluster_name
    service_name = var.ecs_service_name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [var.alb_listener_http_arn]
      }
      test_traffic_route {
        listener_arns = [var.alb_listener_test_arn]
      }
      # Original(Blue)を最初に定義
      target_group {
        name = aws_lb_target_group.blue.name
      }
      # Replacement(Green)を二番目に定義
      target_group {
        name = aws_lb_target_group.green.name
      }
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }

  alarm_configuration {
    enabled = true
    alarms = [
      var.canary_error_rate_alarm_name,
      var.canary_response_time_alarm_name
    ]
  }

  tags = {
    Name        = "${var.project_name}-dg"
    Project     = var.project_name
    Environment = var.environment
  }
}