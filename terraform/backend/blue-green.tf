# terraform/backend/blue-green.tf
# 企業レベルBlue/Green Deployment設定

# --- Blue/Green切り替え用変数 ---
variable "active_environment" {
  description = "Active environment for Blue/Green deployment (blue or green)"
  type        = string
  default     = "blue"
  
  validation {
    condition     = contains(["blue", "green"], var.active_environment)
    error_message = "Active environment must be either 'blue' or 'green'."
  }
}

# --- Green Environment ECS Service ---
resource "aws_ecs_service" "green" {
  name                              = "${var.project_name}-green-service"
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = aws_ecs_task_definition.api.arn
  desired_count                     = 0  # 初期状態では停止
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 60
  
  network_configuration {
    subnets          = data.aws_subnets.public.ids
    security_groups  = [aws_security_group.ecs_service_sg.id]
    assign_public_ip = true
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.green.arn
    container_name   = "${var.project_name}-container"
    container_port   = var.container_port
  }
  
  tags = {
    Name = "${var.project_name}-green-service"
    Environment = "green"
  }
  
  depends_on = [aws_lb_listener.http, aws_db_instance.postgres]
  
  lifecycle {
    ignore_changes = [desired_count]  # 手動スケーリングを許可
  }
}

# --- CloudWatch Alarms for Blue/Green Monitoring ---
resource "aws_cloudwatch_metric_alarm" "blue_health_check" {
  alarm_name          = "${var.project_name}-blue-health-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "Blue environment health check alarm"
  
  dimensions = {
    TargetGroup  = aws_lb_target_group.blue.arn_suffix
    LoadBalancer = aws_lb.main.arn_suffix
  }
  
  tags = {
    Environment = "blue"
  }
}

resource "aws_cloudwatch_metric_alarm" "green_health_check" {
  alarm_name          = "${var.project_name}-green-health-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "Green environment health check alarm"
  
  dimensions = {
    TargetGroup  = aws_lb_target_group.green.arn_suffix
    LoadBalancer = aws_lb.main.arn_suffix
  }
  
  tags = {
    Environment = "green"
  }
}