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

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "hamilcar-hannibal.click"
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket name for frontend assets"
  type        = string
  default     = "nestjs-hannibal-3-frontend"
}

variable "frontend_build_path" {
  description = "Path to the frontend build directory"
  type        = string
  default     = "../../../client/dist"
}

variable "acm_certificate_arn_us_east_1" {
  description = "ACM certificate ARN in us-east-1 for CloudFront"
  type        = string
}

variable "cloudfront_oac_id" {
  description = "CloudFront Origin Access Control ID"
  type        = string
  default     = "E1EA19Y8SLU52D"
}

variable "enable_cloudfront" {
  description = "Whether to enable CloudFront distribution"
  type        = bool
  default     = true
}

variable "alb_origin_verify_header_value" {
  description = "Secret value for ALB origin verification header"
  type        = string
  sensitive   = true
}
