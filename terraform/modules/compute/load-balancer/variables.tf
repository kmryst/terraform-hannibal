variable "project_name" {
  description = "Name of the project"
  type        = string
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

variable "blue_target_group_arn" {
  description = "ARN of the blue target group"
  type        = string
}

variable "green_target_group_arn" {
  description = "ARN of the green target group"
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
