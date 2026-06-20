output "db_instance_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.db_instance_endpoint
}

output "db_instance_id" {
  description = "RDS instance identifier"
  value       = module.rds.db_instance_id
}

output "master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret for master user credentials"
  value       = module.rds.master_user_secret_arn
}
