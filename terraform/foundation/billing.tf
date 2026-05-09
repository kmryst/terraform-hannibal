# AWS Budgets - 月次コスト通知
# 上限 $50・4閾値。deploy/destroy を都度手動実行するプロジェクト向けの設定。

resource "aws_budgets_budget" "monthly_cost" {
  name         = "aws-account-monthly-cost"
  budget_type  = "COST"
  limit_amount = "50"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  time_period_start = "2026-05-01_00:00"
  time_period_end   = "2030-12-31_00:00"

  # 実績 $10 超過（20%）
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 20
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  # 実績 $25 超過（50%）
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  # 予測 $40 超過（80%予測）
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }

  # 実績 $50 超過（100%）
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
}

output "budget_names" {
  description = "Monthly cost budget name"
  value       = aws_budgets_budget.monthly_cost.name
}
