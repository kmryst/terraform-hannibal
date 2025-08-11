# scripts/deployment/deploy-codedeploy.ps1
# Enterprise-level CodeDeploy Blue/Green deployment for ECS
# Based on Netflix/Airbnb/Spotify patterns

param(
    [Parameter(Mandatory=$true)]
    [string]$ImageTag,
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [string]$DeploymentConfig = "CodeDeployDefault.ECSAllAtOnce",
    
    [Parameter(Mandatory=$false)]
    [int]$TimeoutMinutes = 30
)

$ErrorActionPreference = "Stop"

# 企業レベル設定
$ProjectName = "nestjs-hannibal-3"
$Region = "ap-northeast-1"
$AccountId = "258632448142"
$EcrRepository = "$AccountId.dkr.ecr.$Region.amazonaws.com/$ProjectName"

Write-Host "🏢 Starting Enterprise CodeDeploy Blue/Green deployment..." -ForegroundColor Green
Write-Host "📦 Image: $EcrRepository`:$ImageTag" -ForegroundColor Yellow
Write-Host "🌍 Environment: $Environment" -ForegroundColor Cyan
Write-Host "⚙️  Deployment Config: $DeploymentConfig" -ForegroundColor Magenta

# 企業レベルタスク定義作成
Write-Host "📋 Creating enterprise task definition..." -ForegroundColor Blue

# 現在のタスク定義を取得してベースとして使用
$currentTaskDef = aws ecs describe-task-definition --task-definition "$ProjectName-api-task" --query 'taskDefinition' | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to retrieve current task definition"
    exit 1
}

# 企業レベル環境変数設定
$enterpriseEnvironment = @(
    @{ name = "PORT"; value = "3000" },
    @{ name = "HOST"; value = "0.0.0.0" },
    @{ name = "NODE_ENV"; value = "production" },
    @{ name = "CLIENT_URL"; value = "https://hamilcar-hannibal.click" },
    @{ name = "DEPLOYMENT_ID"; value = (Get-Date -Format "yyyyMMdd-HHmmss") },
    @{ name = "IMAGE_TAG"; value = $ImageTag },
    @{ name = "ENVIRONMENT"; value = $Environment }
)

# 新しいタスク定義を作成（既存設定を継承）
$newTaskDef = @{
    family = $currentTaskDef.family
    requiresCompatibilities = $currentTaskDef.requiresCompatibilities
    networkMode = $currentTaskDef.networkMode
    cpu = $currentTaskDef.cpu
    memory = $currentTaskDef.memory
    executionRoleArn = $currentTaskDef.executionRoleArn
    containerDefinitions = @(
        @{
            name = $currentTaskDef.containerDefinitions[0].name
            image = "$EcrRepository`:$ImageTag"
            cpu = $currentTaskDef.containerDefinitions[0].cpu
            memory = $currentTaskDef.containerDefinitions[0].memory
            essential = $currentTaskDef.containerDefinitions[0].essential
            portMappings = $currentTaskDef.containerDefinitions[0].portMappings
            environment = $enterpriseEnvironment
            logConfiguration = $currentTaskDef.containerDefinitions[0].logConfiguration
        }
    )
}

$taskDefJson = $newTaskDef | ConvertTo-Json -Depth 10

# タスク定義を登録
$taskDefArn = aws ecs register-task-definition --cli-input-json $taskDefJson --query 'taskDefinition.taskDefinitionArn' --output text

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to register task definition"
    exit 1
}

Write-Host "✅ Task definition registered: $taskDefArn" -ForegroundColor Green

# 企業レベルCodeDeployデプロイメント設定
$appSpecContent = @"
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: $taskDefArn
        LoadBalancerInfo:
          ContainerName: $ProjectName-container
          ContainerPort: 3000
        PlatformVersion: LATEST
Hooks:
  - BeforeInstall: "echo '🔧 準備フェーズ：新しいタスク定義の登録を準備'"
  - AfterInstall: "echo '📦 インストール完了：新しいタスク定義が登録されました'"
  - AfterAllowTestTraffic: "echo '🧪 テストトラフィック許可：動作検証を実施中'"
  - BeforeAllowTraffic: "echo '🚦 プロダクショントラフィック切り替え前アクション'"
  - AfterAllowTraffic: "echo '🎉 プロダクショントラフィックへ切り替え完了'"
"@

# デプロイメント実行（企業レベル設定）
Write-Host "🚀 Starting enterprise CodeDeploy deployment..." -ForegroundColor Blue

$deploymentId = aws deploy create-deployment --application-name "$ProjectName-codedeploy-app" --deployment-group-name "$ProjectName-deployment-group" --deployment-config-name $DeploymentConfig --revision "revisionType=AppSpecContent,appSpecContent={content='$appSpecContent'}" --query 'deploymentId' --output text

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create enterprise deployment"
    exit 1
}

Write-Host "✅ Enterprise deployment started: $deploymentId" -ForegroundColor Green
Write-Host "⚙️  Using deployment config: $DeploymentConfig" -ForegroundColor Magenta

# 企業レベル監視とログ出力
Write-Host "⏳ Monitoring enterprise deployment progress..." -ForegroundColor Yellow
$startTime = Get-Date
$timeoutTime = $startTime.AddMinutes($TimeoutMinutes)

do {
    Start-Sleep -Seconds 30
    $currentTime = Get-Date
    $elapsed = ($currentTime - $startTime).TotalMinutes
    
    $deploymentInfo = aws deploy get-deployment --deployment-id $deploymentId --query 'deploymentInfo' | ConvertFrom-Json
    $status = $deploymentInfo.status
    
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Status: $status (Elapsed: $([math]::Round($elapsed, 1)) min)" -ForegroundColor Cyan
    
    if ($currentTime -gt $timeoutTime) {
        Write-Host "⏰ Deployment timeout after $TimeoutMinutes minutes" -ForegroundColor Red
        aws deploy stop-deployment --deployment-id $deploymentId --auto-rollback-enabled
        exit 1
    }
    
} while ($status -eq "InProgress" -or $status -eq "Queued" -or $status -eq "Ready")

if ($status -eq "Succeeded") {
    $totalTime = [math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)
    Write-Host "🎉 Enterprise deployment completed successfully!" -ForegroundColor Green
    Write-Host "📊 Total deployment time: $totalTime minutes" -ForegroundColor Cyan
    
    # ALB情報表示
    $albDns = aws elbv2 describe-load-balancers --names "$ProjectName-alb" --query 'LoadBalancers[0].DNSName' --output text
    Write-Host "🌐 Production URL: http://$albDns" -ForegroundColor Yellow
    Write-Host "🧪 Test URL: http://$albDns`:8080" -ForegroundColor Yellow
    Write-Host "📈 CloudWatch Logs: /aws/codedeploy/$ProjectName" -ForegroundColor Magenta
    
    # デプロイメント結果サマリー
    Write-Host "📋 Deployment Summary:" -ForegroundColor White
    Write-Host "  - Image: $EcrRepository`:$ImageTag" -ForegroundColor Gray
    Write-Host "  - Environment: $Environment" -ForegroundColor Gray
    Write-Host "  - Config: $DeploymentConfig" -ForegroundColor Gray
    Write-Host "  - Duration: $totalTime minutes" -ForegroundColor Gray
    
} else {
    Write-Host "❌ Enterprise deployment failed with status: $status" -ForegroundColor Red
    
    # エラー情報表示
    if ($deploymentInfo.errorInformation) {
        Write-Host "🔍 Error Information:" -ForegroundColor Red
        Write-Host "  Code: $($deploymentInfo.errorInformation.code)" -ForegroundColor Gray
        Write-Host "  Message: $($deploymentInfo.errorInformation.message)" -ForegroundColor Gray
    }
    
    # CloudWatchログの取得を試みる
    try {
        Write-Host "📄 Recent CloudWatch logs:" -ForegroundColor Yellow
        aws logs describe-log-streams --log-group-name "/aws/codedeploy/$ProjectName" --order-by LastEventTime --descending --max-items 1 --query 'logStreams[0].logStreamName' --output text | ForEach-Object {
            aws logs get-log-events --log-group-name "/aws/codedeploy/$ProjectName" --log-stream-name $_ --limit 5 --query 'events[].message' --output text
        }
    } catch {
        Write-Host "Could not retrieve CloudWatch logs" -ForegroundColor Gray
    }
    
    exit 1
}

Write-Host "🏁 Enterprise CodeDeploy Blue/Green deployment process completed" -ForegroundColor Green