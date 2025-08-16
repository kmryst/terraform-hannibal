variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "alert_email" {
  description = "Email address for cost alerts"
  type        = string
  # デフォルト値なし - terraform.tfvarsで設定
}