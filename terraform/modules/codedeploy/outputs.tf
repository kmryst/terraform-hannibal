output "codedeploy_app_name" {
  description = "Name of the CodeDeploy application"
  value       = aws_codedeploy_app.main.name
}

output "codedeploy_deployment_group_name" {
  description = "Name of the CodeDeploy deployment group"
  value       = aws_codedeploy_deployment_group.main.deployment_group_name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for CodeDeploy artifacts"
  value       = aws_s3_bucket.codedeploy_artifacts.bucket
}