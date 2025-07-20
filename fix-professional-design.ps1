# AWS Professional設計修正スクリプト

# 1. 既存リソースをstateから削除
terraform state rm aws_lb.main
terraform state rm aws_lb_target_group.api
terraform state rm aws_lb_listener.http
terraform state rm aws_security_group.alb_sg
terraform state rm aws_security_group.ecs_service_sg
terraform state rm aws_security_group.rds_sg
terraform state rm aws_db_subnet_group.postgres
terraform state rm aws_db_instance.postgres
terraform state rm aws_s3_bucket_policy.cloudtrail_logs

Write-Host "既存リソースをTerraform stateから削除しました"
Write-Host "次に、GitHub Actionsの段階的デプロイで適切なロールで再作成してください"