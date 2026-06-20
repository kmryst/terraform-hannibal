terraform {
  backend "s3" {
    bucket         = "nestjs-hannibal-3-terraform-state"
    region         = "ap-northeast-1"
    use_lockfile   = true
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

# The PR-specific key is supplied during init because backend configuration
# cannot reference input variables or local values.
