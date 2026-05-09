terraform {
  backend "s3" {
    bucket         = "nestjs-hannibal-3-terraform-state"
    key            = "foundation/terraform.tfstate"
    region         = "ap-northeast-1"
    use_lockfile   = true
    dynamodb_table = "terraform-state-lock" # Legacy DynamoDB lock during migration
    encrypt        = true
  }
}
