variable "s3_bucket_name" {
  description = "Unique S3 bucket name for frontend static files"
  type        = string
}

variable "frontend_build_path" {
  description = "Path to the frontend build artifacts"
  type        = string
  default     = "../../client/dist"
}

variable "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution for S3 bucket policy"
  type        = string
  default     = ""
}