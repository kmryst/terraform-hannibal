variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "enable_cloudfront" {
  description = "Enable CloudFront distribution (disable for dev to save time)"
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "Your custom domain name (e.g., app.example.com)"
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for static files"
  type        = string
}

variable "s3_bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  type        = string
}

variable "api_alb_dns_name" {
  description = "DNS name of the backend API's Application Load Balancer"
  type        = string
}

variable "acm_certificate_arn_us_east_1" {
  description = "ACM Certificate ARN for CloudFront (must be in us-east-1)"
  type        = string
}