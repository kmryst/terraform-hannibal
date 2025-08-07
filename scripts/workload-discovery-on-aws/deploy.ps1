# AWS Workload Discovery on AWS - Deploy Script
# 使用方法: .\deploy.ps1

Write-Host "=== AWS Workload Discovery on AWS - Deploy Script ===" -ForegroundColor Yellow

# スタック名
$STACK_NAME = "workload-discovery"

Write-Host "1. 前提条件確認中..." -ForegroundColor Green

# nestjs-hannibal-3プロジェクトのVPC自動取得
Write-Host "nestjs-hannibal-3プロジェクトのVPC取得中..." -ForegroundColor Cyan
$VPC_ID = aws ec2 describe-vpcs --filters "Name=tag:Name,Values=nestjs-hannibal-3*" --query "Vpcs[0].VpcId" --output text
if ($VPC_ID -and $VPC_ID -ne "None") {
    Write-Host "既存VPC発見: $VPC_ID" -ForegroundColor Green
    $USE_EXISTING_VPC = $true
} else {
    Write-Host "既存VPCが見つかりません。新規VPC作成します" -ForegroundColor Yellow
    $USE_EXISTING_VPC = $false
}

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
# 実証結果に基づく推奨パラメータでデプロイ
if ($USE_EXISTING_VPC) {
    Write-Host "既存VPC使用でネットワーク問題回避、15分間隔で即座利用" -ForegroundColor Green
    aws cloudformation create-stack --stack-name $STACK_NAME --template-body file://workload-discovery-modified.template --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND --parameters ParameterKey=VpcId,ParameterValue=$VPC_ID ParameterKey=AlreadyHaveConfigSetup,ParameterValue=Yes ParameterKey=CreateOpensearchServiceRole,ParameterValue=No ParameterKey=DiscoveryTaskFrequency,ParameterValue=15mins ParameterKey=NeptuneInstanceClass,ParameterValue=db.t4g.medium ParameterKey=OpensearchInstanceType,ParameterValue=t3.small.search
} else {
    Write-Host "新規VPC作成（ネットワーク問題発生の可能性あり）" -ForegroundColor Yellow
    aws cloudformation create-stack --stack-name $STACK_NAME --template-body file://workload-discovery-modified.template --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND --parameters ParameterKey=DiscoveryTaskFrequency,ParameterValue=15mins ParameterKey=NeptuneInstanceClass,ParameterValue=db.t4g.medium ParameterKey=OpensearchInstanceType,ParameterValue=t3.small.search
}

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