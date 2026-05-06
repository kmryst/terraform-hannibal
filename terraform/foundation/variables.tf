variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
  # デフォルト値なし - terraform.tfvarsで設定
}

variable "alert_email" {
  description = "Email address for cost alerts"
  type        = string
  # デフォルト値なし - terraform.tfvarsで設定
}