variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
}

variable "blue_target_group_name" {
  description = "Name of the blue target group"
  type        = string
}

variable "green_target_group_name" {
  description = "Name of the green target group"
  type        = string
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

variable "alb_listener_production_arn" {
  description = "ARN of the ALB production listener"
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
