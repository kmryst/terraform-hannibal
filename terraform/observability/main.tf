# terraform/observability/main.tf
# Game Day演習用のFIS実験テンプレートを、本体のコンテナデプロイ経路(network/database/service/cdn)
# から独立したroot moduleに分離する(Issue #458)。
# カオスエンジニアリング機能(付随的な検証手段)の設定ミスが、本番相当のデプロイ経路
# (ALB/ECS/CodeDeploy)をブロックしないようにするためのblast radius分離。詳細はADR-0029を参照。

data "terraform_remote_state" "service" {
  backend = "s3"

  config = {
    bucket = "nestjs-hannibal-3-terraform-state"
    key    = "service/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

data "aws_caller_identity" "current" {}

locals {
  # terraform/foundationで管理するGame Day用FIS実行ロール(Issue #446)。
  # foundation stateへの参照を避けるため、固定のRole名からARNを組み立てる。
  hannibal_fis_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/HannibalFISRole-Dev"
}

module "fis" {
  source = "../modules/fis"

  project_name             = var.project_name
  ecs_cluster_name         = data.terraform_remote_state.service.outputs.ecs_cluster_name
  ecs_service_name         = data.terraform_remote_state.service.outputs.ecs_service_name
  fis_role_arn             = local.hannibal_fis_role_arn
  stop_condition_alarm_arn = data.terraform_remote_state.service.outputs.slo_error_rate_fast_burn_alarm_arn
}
