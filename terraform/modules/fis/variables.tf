variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster containing the target tasks"
  type        = string
}

variable "ecs_service_name" {
  description = "Name of the ECS service containing the target tasks"
  type        = string
}

variable "fis_role_arn" {
  description = "ARN of the IAM role AWS FIS assumes to run the experiment (HannibalFISRole-Dev, managed in terraform/foundation)"
  type        = string
}

variable "stop_condition_alarm_arn" {
  description = "ARN of the CloudWatch alarm used as the experiment stop condition (SLO error-rate fast-burn alarm)"
  type        = string
}
