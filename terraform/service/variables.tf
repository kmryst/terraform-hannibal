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
