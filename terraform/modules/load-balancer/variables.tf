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

variable "alb_security_group_id" {
  description = "ID of the ALB security group"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB"
  type        = list(string)
}

variable "alb_listener_port" {
  description = "Port for ALB HTTP redirect listener"
  type        = number
  default     = 80
}

variable "alb_certificate_arn" {
  description = "ACM certificate ARN for ALB HTTPS listeners. The certificate must exist in the ALB region."
  type        = string
}

variable "alb_origin_verify_header_name" {
  description = "Header name required for CloudFront-originated ALB requests"
  type        = string
}

variable "alb_origin_verify_header_value" {
  description = "Secret header value required for CloudFront-originated ALB requests"
  type        = string
  sensitive   = true
}
