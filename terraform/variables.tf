variable "project_name" {
  description = "プロジェクト名"
  type        = string
  default     = "nestjs-hannibal"
}

variable "ec2_key_name" {
  description = "EC2インスタンスに使用するキーペア名"
  type        = string
  default     = "hannibal-key"  # 既に作成済みのキーペア名
}

variable "ec2_instance_type" {
  description = "EC2インスタンスタイプ"
  type        = string
  default     = "t2.micro"
}

variable "ec2_ami_id" {
  description = "EC2インスタンスのAMI ID (Amazon Linux 2023)"
  type        = string
  default     = "ami-0bba69335379e17f8"  # Amazon Linux 2023 AMI (ap-northeast-1)
}

variable "ec2_iam_role_name" {
  description = "EC2インスタンスにアタッチするIAMロール名"
  type        = string
  default     = "SSMInstanceProfile"
}

variable "your_ip_address" {
  description = "SSH接続を許可するIPアドレス（x.x.x.x/32形式）"
  type        = string
  default     = "0.0.0.0/0"  # 本番環境では特定のIPアドレスに制限することを強く推奨
}
