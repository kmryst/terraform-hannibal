# terraform/backend/monitoring.tf
# 🔥 NestJS Hannibal 3 - 実務レベル監視・アラートシステム

# --- SNS Topic for Alerts ---
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"

  tags = {
    Name        = "${var.project_name} Alert Topic"
    Environment = "production"
  }
}

# --- SNS Email Subscription ---
resource "aws_sns_topic_subscription" "email_alerts" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# --- ECS Monitoring ---
# ECS CPU使用率監視（実務レベル: 70%）
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.project_name}-ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold" # comparison: コンパリソン 比較 threshold: 閾値
  evaluation_periods  = "2"                    # evaluation: 評価
  metric_name         = "CPUUtilization"       # utilization: 使用
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "ECS CPU utilization is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "breaching" # データが欠損している場合、それを“breaching”（＝しきい値を超えている、アラーム条件を満たしている）とみなす

  dimensions = { # dimensions: 属性、この場合は追加情報 
    ServiceName = var.ecs_service_name
    ClusterName = var.ecs_cluster_name
  }

  tags = {
    Name = "${var.project_name}-ecs-cpu-alarm"
  }
}

# ECS メモリ使用率監視（実務レベル: 75%）
resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name          = "${var.project_name}-ecs-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "75"
  alarm_description   = "ECS Memory utilization is too high - possible memory leak"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "breaching"

  dimensions = {
    ServiceName = var.ecs_service_name
    ClusterName = var.ecs_cluster_name
  }

  tags = {
    Name = "${var.project_name}-ecs-memory-alarm"
  }
}

# ECS タスク異常終了監視
resource "aws_cloudwatch_metric_alarm" "ecs_task_stopped" {
  alarm_name          = "${var.project_name}-ecs-task-stopped"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "RunningTaskCount"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "ECS task has stopped unexpectedly"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "breaching"

  dimensions = {
    ServiceName = var.ecs_service_name
    ClusterName = var.ecs_cluster_name
  }

  tags = {
    Name = "${var.project_name}-ecs-task-alarm"
  }
}

# --- RDS Monitoring ---
# RDS CPU使用率監視（実務レベル: 60%）
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${var.project_name}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "60"
  alarm_description   = "RDS CPU utilization is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  tags = {
    Name = "${var.project_name}-rds-cpu-alarm"
  }
}

# RDS 接続数監視（実務レベル: 12/20）
resource "aws_cloudwatch_metric_alarm" "rds_connections_high" {
  alarm_name          = "${var.project_name}-rds-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "12"
  alarm_description   = "RDS connection count is too high - possible connection pool exhaustion"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  tags = {
    Name = "${var.project_name}-rds-connections-alarm"
  }
}

# --- ALB Monitoring: SLO burn-rate alarms (ADR-0026) ---
# docs/operations/slo.md のSLI/SLO(応答時間1秒未満、5xx rate 0.1%未満)をCloudWatch metric mathで算出し、
# multi-window multi-burn-rate(fast burn / slow burn)でSNSに接続する。
# canary-error-rate/canary-response-time(CodeDeploy auto rollback用)とecs-task-stopped(可用性計上の正本)は対象外として維持する。

# エラー率SLI: 5xx count / total request count の ratio(%)。
# 低トラフィック時にratioが暴れるのを避けるため、5分間のリクエスト数が
# var.slo_min_request_count 未満の場合は non-breaching(0%)として扱う(ADR-0026参照)。
resource "aws_cloudwatch_metric_alarm" "slo_error_rate_fast_burn" {
  alarm_name          = "${var.project_name}-slo-error-rate-fast-burn"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = var.slo_error_budget_percent * var.slo_error_rate_fast_burn_multiplier
  alarm_description   = "Error budget fast burn: 5xx rate SLI is consuming the monthly error budget rapidly (5min window)"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "e5xx"
    return_data = false
    metric {
      metric_name = "HTTPCode_Target_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Sum"
      dimensions = {
        LoadBalancer = var.alb_arn_suffix
      }
    }
  }

  metric_query {
    id          = "ereq"
    return_data = false
    metric {
      metric_name = "RequestCount"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Sum"
      dimensions = {
        LoadBalancer = var.alb_arn_suffix
      }
    }
  }

  metric_query {
    id          = "error_ratio"
    label       = "5xx error rate SLI (%)"
    expression  = "IF(ereq >= ${var.slo_min_request_count}, (e5xx / ereq) * 100, 0)"
    return_data = true
  }

  tags = {
    Name = "${var.project_name}-slo-error-rate-fast-burn-alarm"
  }
}

resource "aws_cloudwatch_metric_alarm" "slo_error_rate_slow_burn" {
  alarm_name          = "${var.project_name}-slo-error-rate-slow-burn"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 6 # 300s x 6 = 30分window
  threshold           = var.slo_error_budget_percent * var.slo_error_rate_slow_burn_multiplier
  alarm_description   = "Error budget slow burn: 5xx rate SLI is sustained above the SLO over a longer window (30min)"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "e5xx"
    return_data = false
    metric {
      metric_name = "HTTPCode_Target_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Sum"
      dimensions = {
        LoadBalancer = var.alb_arn_suffix
      }
    }
  }

  metric_query {
    id          = "ereq"
    return_data = false
    metric {
      metric_name = "RequestCount"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Sum"
      dimensions = {
        LoadBalancer = var.alb_arn_suffix
      }
    }
  }

  metric_query {
    id          = "error_ratio"
    label       = "5xx error rate SLI (%)"
    expression  = "IF(ereq >= ${var.slo_min_request_count}, (e5xx / ereq) * 100, 0)"
    return_data = true
  }

  tags = {
    Name = "${var.project_name}-slo-error-rate-slow-burn-alarm"
  }
}

# 応答時間SLI: 平均TargetResponseTime / SLO目標値(1秒) の比率(burn ratio)。
# ALBはリクエストごとの遅延ヒストグラムを提供しないため、平均応答時間としきい値の比を
# burn rateの近似として扱う(ADR-0026で限界と代替案を記載)。
resource "aws_cloudwatch_metric_alarm" "slo_response_time_fast_burn" {
  alarm_name          = "${var.project_name}-slo-response-time-fast-burn"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = var.slo_response_time_fast_burn_multiplier
  alarm_description   = "Error budget fast burn: response time SLI is far above the SLO target (5min window)"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "resp_time"
    return_data = false
    metric {
      metric_name = "TargetResponseTime"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Average"
      dimensions = {
        LoadBalancer = var.alb_arn_suffix
      }
    }
  }

  metric_query {
    id          = "resp_ratio"
    label       = "Response time SLI (burn ratio)"
    expression  = "resp_time / ${var.slo_response_time_target_seconds}"
    return_data = true
  }

  tags = {
    Name = "${var.project_name}-slo-response-time-fast-burn-alarm"
  }
}

resource "aws_cloudwatch_metric_alarm" "slo_response_time_slow_burn" {
  alarm_name          = "${var.project_name}-slo-response-time-slow-burn"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 6 # 300s x 6 = 30分window
  threshold           = var.slo_response_time_slow_burn_multiplier
  alarm_description   = "Error budget slow burn: response time SLI is sustained above the SLO target over a longer window (30min)"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "resp_time"
    return_data = false
    metric {
      metric_name = "TargetResponseTime"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Average"
      dimensions = {
        LoadBalancer = var.alb_arn_suffix
      }
    }
  }

  metric_query {
    id          = "resp_ratio"
    label       = "Response time SLI (burn ratio)"
    expression  = "resp_time / ${var.slo_response_time_target_seconds}"
    return_data = true
  }

  tags = {
    Name = "${var.project_name}-slo-response-time-slow-burn-alarm"
  }
}

# --- Synthetics canary availability (time-based availability SLI, ADR-0030) ---
# canaryの成功/失敗はSuccessPercent(0 or 100)の二値でしか得られないため、
# ratioではなく1時間平均をtime-based availabilityの近似として扱う(ADR-0030参照)。
# synthetics_canary_nameが空文字の場合(canary無効時)はアラームを作成しない。
resource "aws_cloudwatch_metric_alarm" "synthetics_availability" {
  count               = var.synthetics_canary_name != "" ? 1 : 0
  alarm_name          = "${var.project_name}-synthetics-availability-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  period              = 3600 # 1時間平均。低頻度実行のSuccessPercentのratio暴れを避ける(ADR-0030)
  metric_name         = "SuccessPercent"
  namespace           = "CloudWatchSynthetics"
  statistic           = "Average"
  threshold           = var.synthetics_availability_target_percent
  alarm_description   = "User-journey canary time-based availability dropped below the SLO target over the last hour"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  # canaryが1時間まったく実行結果を報告しない場合、canary自体(Lambda実行)が壊れている可能性が高いため
  # ECS系アラームと同様にbreachingとして扱う(ADR-0026の非対称設計を踏襲、ALB系のnotBreachingとは異なる)
  treat_missing_data = "breaching"

  dimensions = {
    CanaryName = var.synthetics_canary_name
  }

  tags = {
    Name = "${var.project_name}-synthetics-availability-alarm"
  }
}

# --- Canary Deployment Monitoring ---
# カナリアデプロイ用エラー率監視（5%以上でロールバック）
resource "aws_cloudwatch_metric_alarm" "canary_error_rate" {
  alarm_name          = "${var.project_name}-canary-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "3"
  alarm_description   = "Canary deployment error rate too high - auto rollback triggered"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = {
    Name = "${var.project_name}-canary-error-alarm"
  }
}

# カナリアデプロイ用レスポンス時間監視（2秒以上でロールバック）
resource "aws_cloudwatch_metric_alarm" "canary_response_time" {
  alarm_name          = "${var.project_name}-canary-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "2"
  alarm_description   = "Canary deployment response time too high - auto rollback triggered"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = {
    Name = "${var.project_name}-canary-response-alarm"
  }
}

# --- CloudWatch Dashboard ---
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "hannibal-system-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 6
        height = 6

        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", var.ecs_service_name, "ClusterName", var.ecs_cluster_name],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "ECS CPU & Memory Utilization"
          period  = 300
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 6
        y      = 0
        width  = 6
        height = 6

        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_instance_id],
            [".", "DatabaseConnections", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "RDS CPU & Connections"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix],
            [".", "HTTPCode_Target_2XX_Count", ".", "."],
            [".", "HTTPCode_Target_4XX_Count", ".", "."],
            [".", "HTTPCode_Target_5XX_Count", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "ALB Response Time & HTTP Status Codes"
          period  = 300
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          query  = "SOURCE '/ecs/${var.project_name}-api-task'\\n| fields @timestamp, @message\\n| filter @message like /ERROR/\\n| sort @timestamp desc\\n| limit 20"
          region = var.aws_region
          title  = "Recent Error Logs"
        }
      }
    ]
  })
}