variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where target groups will be created"
  type        = string
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 3000
}

variable "health_check_path" {
  description = "Path for ALB health check"
  type        = string
  default     = "/health"
}

variable "deployment_type" {
  description = "Deployment type (canary/bluegreen)"
  type        = string
  default     = "canary"
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "ecs_service_name" {
  description = "Name of the ECS service"
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

variable "canary_error_rate_alarm_name" {
  description = "Name of the canary error rate alarm"
  type        = string
}

variable "canary_response_time_alarm_name" {
  description = "Name of the canary response time alarm"
  type        = string
}