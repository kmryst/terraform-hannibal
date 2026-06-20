variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 3000
}

variable "cloudfront_origin_facing_prefix_list_id" {
  description = "AWS managed prefix list ID for CloudFront origin-facing addresses"
  type        = string
}