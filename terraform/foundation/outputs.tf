# terraform/foundation/outputs.tf

output "pr_plan_role_arn" {
  description = "ARN of HannibalPRPlanRole-Dev for use in PR terraform plan workflow (#122)"
  value       = aws_iam_role.hannibal_pr_plan_role.arn
}
