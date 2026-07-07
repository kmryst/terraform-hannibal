output "canary_name" {
  description = "Name of the Synthetics canary"
  value       = aws_synthetics_canary.user_journey.name
}

output "canary_arn" {
  description = "ARN of the Synthetics canary"
  value       = aws_synthetics_canary.user_journey.arn
}

output "canary_artifacts_bucket_name" {
  description = "S3 bucket name that stores canary run artifacts"
  value       = aws_s3_bucket.canary_artifacts.bucket
}

output "canary_execution_role_arn" {
  description = "IAM role ARN assumed by the canary execution Lambda"
  value       = aws_iam_role.canary_execution.arn
}
