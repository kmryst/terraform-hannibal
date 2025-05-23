# terraform/frontend/variables.tf
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "nestjs-hannibal-3-frontend"
}

variable "s3_bucket_name" {
  description = "Unique S3 bucket name for frontend static files"
  type        = string
  default     = "nestjs-hannibal-3-frontend" # グローバルにユニークな名前を設定
}

variable "frontend_build_path" {
  description = "Path to the frontend build artifacts"
  type        = string
  default     = "../../client/dist" # <PROJECT_ROOT>/client/dist を指す相対パス
}

variable "api_alb_dns_name" {
  description = "DNS name of the backend API's Application Load Balancer"
  type        = string
  # この値はバックエンドのTerraform apply後に取得して設定する
}

# (オプション) Route 53 独自ドメイン設定用
# variable "domain_name" {
#   description = "Your custom domain name (e.g., app.example.com)"
#   type        = string
#   default     = ""
# }

# variable "hosted_zone_id" {
#   description = "Route 53 Hosted Zone ID for the domain_name"
#   type        = string
#   default     = ""
# }

# variable "acm_certificate_arn_us_east_1" {
#   description = "ACM Certificate ARN for CloudFront (must be in us-east-1)"
#   type        = string
#   default     = ""
# }
