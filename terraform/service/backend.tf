terraform {
  backend "s3" {
    bucket         = "nestjs-hannibal-3-terraform-state"
    key            = "service/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
