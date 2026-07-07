variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "nestjs-hannibal-3"
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "ecr_repository_url" {
  description = "ECR repository URL for the container image"
  type        = string
}

variable "container_port" {
  description = "Container port for the application"
  type        = number
  default     = 3000
}

variable "desired_task_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 1
}

variable "cpu" {
  description = "CPU units for the ECS task"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memory (MiB) for the ECS task"
  type        = number
  default     = 512
}

variable "alb_certificate_arn" {
  description = "ACM certificate ARN for HTTPS listener"
  type        = string
}

variable "health_check_path" {
  description = "Health check path for target groups"
  type        = string
  default     = "/health"
}

variable "client_url_for_cors" {
  description = "Client URL for CORS configuration"
  type        = string
  default     = ""
}

variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications"
  type        = string
  default     = "gatsbykenji@gmail.com"
}

variable "deployment_type" {
  description = "CodeDeploy deployment type (canary or linear)"
  type        = string
  default     = "canary"

  validation {
    condition     = contains(["canary", "linear"], var.deployment_type)
    error_message = "deployment_type must be either 'canary' or 'linear'."
  }
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "nestjs_hannibal_db"
}

variable "alb_origin_secret_rotation_version" {
  description = "Version key for rotating the ALB origin verify header secret"
  type        = string
  default     = "v1"
}

# --- Synthetics canary settings (ADR-0030, Issue #465) ---

variable "domain_name" {
  description = "Public domain name. terraform/cdn の同名変数と値を揃える(service は cdn より前に apply されるため remote_state 参照ができない)"
  type        = string
  default     = "hamilcar-hannibal.click"
}

variable "enable_synthetics_canary" {
  description = "Synthetics canaryを作成するかどうか。dev環境のオンデマンド運用(ADR-0008)に合わせてtrue/falseを切り替える"
  type        = bool
  default     = true
}

variable "synthetics_canary_name" {
  description = "Synthetics canaryの名前(CloudWatch Syntheticsの制約で21文字以内)"
  type        = string
  default     = "hannibal-canary"
}

variable "synthetics_schedule_expression" {
  description = "Synthetics canaryの実行間隔"
  type        = string
  default     = "rate(5 minutes)"
}

variable "synthetics_graphql_query" {
  description = "canaryが実行するGraphQL読み取り専用クエリ(src/graphql/schema/map.graphqlのcapitalCitiesを使用)"
  type        = string
  default     = "query { capitalCities { type features { type properties { name } } } }"
}
