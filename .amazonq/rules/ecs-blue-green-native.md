# ECS Native Blue/Green Deployment Rules (nestjs-hannibal-3)

Amazon ECS blue/green deployments (Released July 17, 2025)


v6.8.0 のリリース（2025年7月17日）時点では、Amazon ECS ネイティブ Blue/Green デプロイ機能が Terraform ネイティブリソースとして未提供


  deployment_configuration {
    strategy             = "BLUE_GREEN"
    bake_time_in_minutes = 1
# Unexpected block エラーが発生する制約あり