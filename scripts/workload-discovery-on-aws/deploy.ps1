# AWS Workload Discovery on AWS - Deploy Script
# 使用方法: .\deploy.ps1

Write-Host "=== AWS Workload Discovery on AWS - Deploy Script ===" -ForegroundColor Yellow

# スタック名
$STACK_NAME = "workload-discovery"

Write-Host "1. 前提条件確認中..." -ForegroundColor Green

# AWS Config確認
Write-Host "AWS Config状況:" -ForegroundColor Cyan
aws configservice get-status

# OpenSearchServiceロール確認
Write-Host "OpenSearchServiceロール確認:" -ForegroundColor Cyan
aws iam get-role --role-name AWSServiceRoleForAmazonOpenSearchService 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "OpenSearchServiceロールは存在しません（テンプレートで自動作成されます）" -ForegroundColor Yellow
}

Write-Host "2. CloudFormationスタックデプロイ中..." -ForegroundColor Green

# デプロイ実行
aws cloudformation create-stack --stack-name $STACK_NAME --template-body file://workload-discovery-modified.template --capabilities CAPABILITY_IAM

if ($LASTEXITCODE -eq 0) {
    Write-Host "デプロイ開始成功！" -ForegroundColor Green
    Write-Host "予想完了時間: 約30分" -ForegroundColor Yellow
    Write-Host "完了後、WebUIでアーキテクチャ図を確認してください" -ForegroundColor Cyan
    Write-Host "削除する場合: .\destroy.ps1 を実行" -ForegroundColor Yellow
} else {
    Write-Host "デプロイ失敗！エラーを確認してください" -ForegroundColor Red
}

Write-Host "=== デプロイ状況確認 ===" -ForegroundColor Green
aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].StackStatus" --output text