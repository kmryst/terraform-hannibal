# terraform/frontend/outputs.tf
output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for frontend files"
  value       = aws_s3_bucket.frontend_bucket.bucket
}
