# terraform/frontend/outputs.tf
output "cloudfront_domain_name" {
  value       = length(aws_cloudfront_distribution.main) > 0 ? aws_cloudfront_distribution.main[0].domain_name : null
  description = "CloudFrontのドメイン名"
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for frontend files"
  value       = data.aws_s3_bucket.frontend_bucket.bucket
}

output "cloudfront_distribution_id" {
  value       = length(aws_cloudfront_distribution.main) > 0 ? aws_cloudfront_distribution.main[0].id : null
  description = "CloudFrontディストリビューションID"
}
