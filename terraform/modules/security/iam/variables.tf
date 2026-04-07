variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "secrets_manager_secret_arns" {
  description = "List of Secrets Manager secret ARNs the ECS task execution role can read"
  type        = list(string)
  default     = []
}