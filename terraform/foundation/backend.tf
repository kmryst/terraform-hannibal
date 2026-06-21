terraform {
  backend "s3" {
    bucket       = "nestjs-hannibal-3-terraform-state"
    key          = "foundation/terraform.tfstate"
    region       = "ap-northeast-1"
    use_lockfile = true
    encrypt      = true
  }
}
