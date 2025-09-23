output "bucket_id" {
  description = "ID of the S3 bucket"
  value       = data.aws_s3_bucket.frontend_bucket.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = data.aws_s3_bucket.frontend_bucket.arn
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  value       = data.aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
}