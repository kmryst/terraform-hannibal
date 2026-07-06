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
