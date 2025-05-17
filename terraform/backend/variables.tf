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

variable "vpc_id" {
  description = "ID of the VPC for deploying resources. Create a default VPC or use an existing one."
  type        = string
  # 例: "vpc-xxxxxxxxxxxxxxxxx" (実際のVPC IDに置き換えるか、データソースで取得)
  # default     = "vpc-xxxxxxxxxxxxxxxxx" # デフォルトVPCがない場合は指定必須
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB and Fargate tasks (at least 2 in different AZs)"
  type        = list(string)
  # 例: ["subnet-xxxxxxxxxxxxxxxxx", "subnet-yyyyyyyyyyyyyyyyy"]
  # default     = ["subnet-xxxxxxxxxxxxxxxxx", "subnet-yyyyyyyyyyyyyyyyy"] # 指定必須
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for Fargate tasks if using private subnets"
  type        = list(string)
  default     = [] # ALBをパブリックに置く場合は空でも良いが、Fargateはプライベート推奨
}

variable "container_image_uri" {
  description = "ECR URI of the Docker image for the NestJS API"
  type        = string
  # 例: "YOUR_ACCOUNT_ID.dkr.ecr.ap-northeast-1.amazonaws.com/nestjs-hannibal-3:latest"
  # default     = "YOUR_ACCOUNT_ID.dkr.ecr.ap-northeast-1.amazonaws.com/nestjs-hannibal-3:latest" # 事前にECRにpushしたイメージURI
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
  default     = "/graphql" # NestJSのGraphQLエンドポイント (OPTIONSメソッドで200が返るか、または専用ヘルスチェックパス)
}

variable "client_url_for_cors" {
  description = "Frontend CloudFront URL for CORS configuration (e.g., https://dXXXXXXXXXXXXX.cloudfront.net)"
  type        = string
  default     = "" # フロントエンドデプロイ後に設定するか、固定ドメインを指定
}

# (オプション) ACM証明書ARN (HTTPS化する場合)
# variable "certificate_arn" {
#   description = "ARN of the ACM certificate for HTTPS listener"
#   type        = string
#   default     = ""
# }
