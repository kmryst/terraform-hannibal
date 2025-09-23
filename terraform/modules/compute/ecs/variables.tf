variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "ecr_repository_url" {
  description = "ECR repository URL (manually created)"
  type        = string
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 3000
}

variable "desired_task_count" {
  description = "Desired number of Fargate tasks"
  type        = number
  default     = 1
}

variable "cpu" {
  description = "CPU units for Fargate task"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memory in MiB for Fargate task"
  type        = number
  default     = 512
}

variable "client_url_for_cors" {
  description = "Frontend CloudFront URL for CORS configuration"
  type        = string
  default     = ""
}

variable "db_username" {
  description = "Database master username"
  type        = string
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  type        = string
}

variable "app_subnet_ids" {
  description = "List of app subnet IDs for ECS tasks"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "ID of the ECS security group"
  type        = string
}

variable "blue_target_group_arn" {
  description = "ARN of the blue target group"
  type        = string
}

variable "alb_listener_http_arn" {
  description = "ARN of the ALB HTTP listener"
  type        = string
}

variable "alb_listener_test_arn" {
  description = "ARN of the ALB test listener"
  type        = string
}

variable "rds_endpoint" {
  description = "RDS endpoint"
  type        = string
}