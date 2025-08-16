# AWS Budgets for Cost Management
# 5USD～200USDの範囲で5USD刻み

locals {
  budget_amounts = [for i in range(1, 41) : i * 5]
}

resource "aws_budgets_budget" "monthly_cost_budgets" {
  for_each = { for amount in local.budget_amounts : "aws-account-cost-${amount}usd" => amount }

  name         = each.key
  budget_type  = "COST"
  limit_amount = each.value
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  time_period_start = "2025-01-01_09:00"
  time_period_end   = "2030-12-31_09:00"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}

# Output budget names for reference
output "budget_names" {
  description = "List of created budget names"
  value       = keys(aws_budgets_budget.monthly_cost_budgets)
}