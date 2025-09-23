output "distribution_arn" {
  description = "ARN of the CloudFront distribution"
  value       = length(aws_cloudfront_distribution.main) > 0 ? aws_cloudfront_distribution.main[0].arn : ""
}

output "distribution_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = length(aws_cloudfront_distribution.main) > 0 ? aws_cloudfront_distribution.main[0].domain_name : ""
}

output "distribution_hosted_zone_id" {
  description = "Hosted zone ID of the CloudFront distribution"
  value       = length(aws_cloudfront_distribution.main) > 0 ? aws_cloudfront_distribution.main[0].hosted_zone_id : ""
}