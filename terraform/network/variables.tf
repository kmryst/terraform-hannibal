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

variable "container_port" {
  description = "Container port for ECS security group rules"
  type        = number
  default     = 3000
}

variable "cloudfront_origin_facing_prefix_list_id" {
  description = "AWS-managed prefix list ID for CloudFront origin-facing IPs"
  type        = string
  default     = "pl-58a04531"
}
