# terraform/backend/variables.tf
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

# Virtual Private Cloud
# main.tfの data.aws_vpc.selected で default = true を指定しているため、
# デフォルトVPCを自動的に取得します。
# デフォルトVPCが存在しない場合は、この変数にVPC IDを指定する必要があります。
variable "vpc_id" {
  description = "ID of the VPC for deploying resources. If not specified, the default VPC will be used."
  type        = string
  default     = "" # 空文字列をデフォルト値として設定し、オプショナルにする
}

# variable "public_subnet_ids" {
#   description = "List of public subnet IDs for ALB and Fargate tasks (at least 2 in different AZs)"
#   type        = list(string)
#   # 例: ["subnet-xxxxxxxxxxxxxxxxx", "subnet-yyyyyyyyyyyyyyyyy"]
#   # default     = ["subnet-xxxxxxxxxxxxxxxxx", "subnet-yyyyyyyyyyyyyyyyy"] # 指定必須
# }

variable "private_subnet_ids" {
  description = "List of private subnet IDs for Fargate tasks if using private subnets"
  type        = list(string)
  default     = [] # ALBをパブリックに置く場合は空でも良いが、Fargateはプライベート推奨
}

variable "container_image_uri" {
  description = "ECR URI of the Docker image for the NestJS API"
  type        = string
  default     = "258632448142.dkr.ecr.ap-northeast-1.amazonaws.com/nestjs-hannibal-3:latest" # 事前にECRにpushしたイメージURI
}

variable "ecr_repository_url" {
  description = "ECR repository URL (manually created)"
  type        = string
  default     = "258632448142.dkr.ecr.ap-northeast-1.amazonaws.com/nestjs-hannibal-3"
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 3000
}

variable "desired_task_count" {
  description = "Desired number of Fargate tasks"
  type        = number
  default     = 1 # 開発・テスト用。本番では2以上を推奨
}

variable "cpu" {
  description = "CPU units for Fargate task"
  type        = number
  default     = 256 # 0.25 vCPU
}

variable "memory" {
  description = "Memory in MiB for Fargate task"
  type        = number
  default     = 512 # 0.5 GB
}

variable "alb_listener_port" {
  description = "Port for ALB listener"
  type        = number
  default     = 80 # HTTP. HTTPSの場合は443とACM証明書ARNが必要
}

variable "health_check_path" {
  description = "Path for ALB health check"
  type        = string
  default     = "/" # GraphQLエンドポイントではなくルートパス

}

variable "client_url_for_cors" {
  description = "Frontend CloudFront URL for CORS configuration (e.g., https://dXXXXXXXXXXXXX.cloudfront.net)"
  type        = string
  default     = "" # フロントエンドデプロイ後に設定するか、固定ドメインを指定
}

variable "database_url" {
  description = "Database connection URL for application"
  type        = string
  default     = ""
  sensitive   = true
}

# (オプション) ACM証明書ARN (HTTPS化する場合)
# variable "certificate_arn" {
#   description = "ARN of the ACM certificate for HTTPS listener"
#   type        = string
#   default     = ""
# }

# --- Database Variables ---
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
  default     = "15.8"
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
  default     = "hannibal123!" # 本番では AWS Secrets Manager 推奨
  sensitive   = true
}

# --- Monitoring Variables ---
variable "alert_email" {
  description = "Email address for CloudWatch alerts"
  type        = string
  default     = "gatsbykenji@gmail.com"
}

# --- AWS Professional Environment Configuration ---
variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}
