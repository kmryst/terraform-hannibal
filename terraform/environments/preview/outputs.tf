output "environment_name" {
  description = "AWS environment name derived from the pull request number"
  value       = local.environment_name
}

output "resource_prefix" {
  description = "Prefix for AWS resources owned by this preview environment"
  value       = local.resource_prefix
}
