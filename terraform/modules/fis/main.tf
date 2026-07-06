# terraform/modules/fis/main.tf
# Game Day演習用のAWS FIS実験テンプレート(ECSタスク強制停止)。
# 対象タスクの選定はaws:ecs:task resource typeのparameters(cluster/service)で行い、
# COUNT(1)で実行中タスクのうち1つだけをランダムに選ぶ(ADR-0028参照)。
# stop_conditionはIssue #445で作成したSLO error-rate fast-burnアラームに接続し、
# 演習が意図せず利用者影響を悪化させた場合に自動停止する。

resource "aws_fis_experiment_template" "ecs_task_stop" {
  description = "Game Day: force-stop a single ECS task to verify CodeDeploy/ECS automatic recovery and SLO burn-rate alerting"
  role_arn    = var.fis_role_arn

  stop_condition {
    source = "aws:cloudwatch:alarm"
    value  = var.stop_condition_alarm_arn
  }

  target {
    name           = "ecsTask"
    resource_type  = "aws:ecs:task"
    selection_mode = "COUNT(1)"

    parameters = {
      cluster = var.ecs_cluster_name
      service = var.ecs_service_name
    }
  }

  action {
    name      = "stopTask"
    action_id = "aws:ecs:stop-task"

    target {
      key   = "Tasks"
      value = "ecsTask"
    }
  }

  experiment_options {
    account_targeting            = "single-account"
    empty_target_resolution_mode = "fail"
  }

  tags = {
    Name    = "${var.project_name}-game-day-ecs-task-stop"
    Purpose = "GameDay"
  }
}
