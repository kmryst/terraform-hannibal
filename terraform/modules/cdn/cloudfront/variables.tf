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

variable "api_origin_domain_name" {
  description = "Custom domain name of the backend API origin"
  type        = string
}

variable "acm_certificate_arn_us_east_1" {
  description = "ACM Certificate ARN for CloudFront (must be in us-east-1)"
  type        = string
}

variable "cloudfront_oac_id" {
  description = "ID of the existing CloudFront Origin Access Control for S3."
  type        = string
}

variable "alb_origin_verify_header_name" {
  description = "Header name CloudFront adds when forwarding API requests to the ALB origin"
  type        = string
}

variable "alb_origin_verify_header_value" {
  description = "Secret header value CloudFront adds when forwarding API requests to the ALB origin"
  type        = string
  sensitive   = true
}
