# ECS Native Blue/Green Deployment Trigger
# 
# 用途: Dockerイメージのみアップデート（インフラ変更なし）
# - アプリケーションコードの変更のみデプロイ
# - 開発中の頻繁なデプロイ
# - ホットフィックスの適用
# - 特定バージョンへのロールバック
#
# 使用例:
# .\.\scripts\deployment\deploy-blue-green.ps1                    # latestタグでデプロイ
# .\.\scripts\deployment\deploy-blue-green.ps1 -ImageTag "v1.2.3"   # 特定バージョンでデプロイ
# .\.\scripts\deployment\deploy-blue-green.ps1 -ImageTag "v1.1.0"   # ロールバック
#
# 注意: 事前にECRにイメージがpushされている必要があります

param(
    [string]$ProjectName = "nestjs-hannibal-3",
    [string]$Region = "ap-northeast-1",
    [string]$ImageTag = "latest"
)

Write-Host "=== ECS Native Blue/Green Deployment ===" -ForegroundColor Green

$ClusterName = "$ProjectName-cluster"
$ServiceName = "$ProjectName-api-service"
$TaskFamily = "$ProjectName-api-task"

# Get current task definition
$CurrentTaskDef = aws ecs describe-task-definition --task-definition $TaskFamily --region $Region --query 'taskDefinition.taskDefinitionArn' --output text

Write-Host "Current Task Definition: $CurrentTaskDef" -ForegroundColor Yellow

# Trigger deployment with new image tag
Write-Host "`nTriggering Blue/Green deployment..." -ForegroundColor Cyan
aws ecs update-service --cluster $ClusterName --service $ServiceName --task-definition "${TaskFamily}:${ImageTag}" --region $Region --query 'service.{ServiceName:serviceName,Status:status,TaskDefinition:taskDefinition}' --output table

Write-Host "`nDeployment initiated. Monitor progress with:" -ForegroundColor Green
Write-Host "..\monitoring\blue-green-status.ps1" -ForegroundColor White

Write-Host "`nBake time: ECS automatic (typically 1-2 minutes)" -ForegroundColor Yellow
Write-Host "Production traffic will switch after successful health checks" -ForegroundColor Yellow