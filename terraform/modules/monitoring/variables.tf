variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "alert_email" {
  description = "Email address for CloudWatch alerts"
  type        = string
}

variable "ecs_service_name" {
  description = "Name of the ECS service"
  type        = string
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "rds_instance_id" {
  description = "ID of the RDS instance"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the Application Load Balancer"
  type        = string
}

# --- SLO burn-rate alarm settings (ADR-0026) ---
# 数値の正本は docs/operations/slo.md。ここでは metric math 用のしきい値・window を定義する。

variable "slo_error_budget_percent" {
  description = "SLOで許容する5xx error rateの目標値(%)。docs/operations/slo.mdの月次エラー率0.1%が正本"
  type        = number
  default     = 0.1
}

variable "slo_error_rate_fast_burn_multiplier" {
  description = "fast burn(短時間窓)アラームのerror budget消費倍率。Google SRE本のmulti-window multi-burn-rate例に準拠(約14.4x)"
  type        = number
  default     = 14.4
}

variable "slo_error_rate_slow_burn_multiplier" {
  description = "slow burn(長時間窓)アラームのerror budget消費倍率"
  type        = number
  default     = 3
}

variable "slo_min_request_count" {
  description = "error rate SLIをratioとして評価するために必要な最小リクエスト数(5分間)。これ未満の場合はratioの暴れを避けるためnon-breaching扱いにする(ADR-0026参照)"
  type        = number
  default     = 20
}

variable "slo_response_time_target_seconds" {
  description = "応答時間SLOの目標値(秒)。docs/operations/slo.mdの1秒未満が正本"
  type        = number
  default     = 1
}

variable "slo_response_time_fast_burn_multiplier" {
  description = "response time SLIのfast burnしきい値倍率(平均応答時間がSLO目標の何倍で発報するか)"
  type        = number
  default     = 2
}

variable "slo_response_time_slow_burn_multiplier" {
  description = "response time SLIのslow burnしきい値倍率"
  type        = number
  default     = 1.2
}

# --- Synthetics canary availability (ADR-0030, Issue #467) ---

variable "synthetics_canary_name" {
  description = "Synthetics canaryの名前。空文字の場合は稼働率アラームを作成しない(canary無効時)"
  type        = string
  default     = ""
}

variable "synthetics_availability_target_percent" {
  description = "canaryのtime-based availability目標値(%)。docs/operations/slo.mdの稼働率SLOが正本"
  type        = number
  default     = 99.5
}