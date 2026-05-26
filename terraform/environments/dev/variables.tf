# terraform/environments/dev/variables.tf
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "nestjs-hannibal-3"
}

variable "ecr_repository_url" {
  description = "ECR repository URL (manually created)"
  type        = string
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 3000
}

variable "desired_task_count" {
  description = "Desired number of Fargate tasks"
  type        = number
  default     = 1
}

variable "cpu" {
  description = "CPU units for Fargate task"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memory in MiB for Fargate task"
  type        = number
  default     = 512
}

variable "alb_listener_port" {
  description = "Port for ALB listener"
  type        = number
  default     = 80
}

variable "alb_certificate_arn" {
  description = "ACM certificate ARN for ALB HTTPS listeners. The certificate must exist in aws_region."
  type        = string
}

variable "health_check_path" {
  description = "Path for ALB health check"
  type        = string
  default     = "/health"
}

variable "client_url_for_cors" {
  description = "Frontend CloudFront URL for CORS configuration"
  type        = string
  default     = ""
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.14"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "nestjs_hannibal_db"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
  default     = null
}

variable "manage_master_user_password" {
  description = "If true, RDS manages the master password in Secrets Manager automatically (recommended). Requires secretsmanager:* on the CICD role and boundary."
  type        = bool
  default     = true
}

variable "alert_email" {
  description = "Email address for CloudWatch alerts"
  type        = string
  default     = "gatsbykenji@gmail.com"
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "deployment_type" {
  description = "Deployment type (canary/bluegreen)"
  type        = string
  default     = "canary"
  validation {
    condition     = contains(["canary", "bluegreen"], var.deployment_type)
    error_message = "Deployment type must be canary or bluegreen."
  }
}

# --- Frontend Variables ---
variable "s3_bucket_name" {
  description = "Unique S3 bucket name for frontend static files"
  type        = string
  default     = "nestjs-hannibal-3-frontend"
}

variable "frontend_build_path" {
  description = "Path to the frontend build artifacts"
  type        = string
  default     = "../../../client/dist"
}

variable "domain_name" {
  description = "Your custom domain name (e.g., app.example.com)"
  type        = string
  default     = "hamilcar-hannibal.click"
}

variable "hosted_zone_id" {
  description = "Route 53 Hosted Zone ID for the domain_name"
  type        = string
}

variable "acm_certificate_arn_us_east_1" {
  description = "ACM Certificate ARN for CloudFront (must be in us-east-1)"
  type        = string
}

variable "cloudfront_oac_id" {
  description = "ID of the existing CloudFront Origin Access Control for S3. The OAC is managed outside Terraform (manually created)."
  type        = string
  default     = "E1EA19Y8SLU52D"
}

variable "enable_cloudfront" {
  description = "Enable CloudFront distribution (disable for dev to save time)"
  type        = bool
  default     = true
}

variable "alb_origin_secret_rotation_version" {
  description = "Version string used to rotate the CloudFront-to-ALB origin verification secret."
  type        = string
  default     = "v1"
}
