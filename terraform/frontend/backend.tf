terraform {
  backend "s3" {
    bucket         = "nestjs-hannibal-3-terraform-state" # 既存のS3バケット名に合わせて修正してください
    key            = "frontend/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "terraform-state-lock"     # DynamoDB State Lock
    encrypt        = true
  }
} 