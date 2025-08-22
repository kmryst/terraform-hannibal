terraform {
  backend "s3" {                                 # ここでTerraformの状態ファイル（tfstate）をAWS S3バケットで管理することを指定しています。"s3"はバックエンドの種類で、リモートでの一元管理やチーム開発、CI/CDに最適です。
    bucket         = "nestjs-hannibal-3-terraform-state" # 既存のS3バケット名に合わせて修正してください
    key            = "backend/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "terraform-state-lock"     # DynamoDB State Lock
    encrypt        = true
  }
}
