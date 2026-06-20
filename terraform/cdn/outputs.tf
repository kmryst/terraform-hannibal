output "cloudfront_distribution_domain_name" {
  description = "CloudFront distribution domain name"
  value       = module.cloudfront.distribution_domain_name
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = module.cloudfront.distribution_arn
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (extracted from ARN)"
  value       = element(split("/", module.cloudfront.distribution_arn), length(split("/", module.cloudfront.distribution_arn)) - 1)
}

output "s3_bucket_id" {
  description = "S3 bucket ID"
  value       = module.s3.bucket_id
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = var.s3_bucket_name
}
