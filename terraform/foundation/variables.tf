variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
  # デフォルト値なし - terraform.tfvarsで設定
}

variable "cacoo_aws_account_id" {
  description = "Cacoo AWS account ID for diagram integration"
  type        = string
  default     = "631054961367"
}

variable "alert_email" {
  description = "Email address for cost alerts"
  type        = string
  # デフォルト値なし - terraform.tfvarsで設定
}