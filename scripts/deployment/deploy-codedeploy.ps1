# scripts/deployment/deploy-codedeploy.ps1

param(
    [Parameter(Mandatory=$true)]
    [string]$ImageTag,
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev"
)

$ErrorActionPreference = "Stop"

# 設定
$ProjectName = "nestjs-hannibal-3"
$Region = "ap-northeast-1"
$AccountId = "258632448142"
$EcrRepository = "$AccountId.dkr.ecr.$Region.amazonaws.com/$ProjectName"

Write-Host "🚀 Starting CodeDeploy Blue/Green deployment..." -ForegroundColor Green
Write-Host "Image: $EcrRepository`:$ImageTag" -ForegroundColor Yellow

# 新しいタスク定義を作成
Write-Host "📝 Creating new task definition..." -ForegroundColor Blue

$taskDefJson = @{
    family = "$ProjectName-api-task"
    requiresCompatibilities = @("FARGATE")
    networkMode = "awsvpc"
    cpu = "1024"
    memory = "2048"
    executionRoleArn = "arn:aws:iam::$AccountId`:role/$ProjectName-ecs-task-execution-role"
    containerDefinitions = @(
        @{
            name = "$ProjectName-container"
            image = "$EcrRepository`:$ImageTag"
            cpu = 1024
            memory = 2048
            essential = $true
            portMappings = @(
                @{
                    containerPort = 3000
                    hostPort = 3000
                    protocol = "tcp"
                }
            )
            environment = @(
                @{ name = "PORT"; value = "3000" },
                @{ name = "HOST"; value = "0.0.0.0" },
                @{ name = "NODE_ENV"; value = "production" }
            )
            logConfiguration = @{
                logDriver = "awslogs"
                options = @{
                    "awslogs-group" = "/ecs/$ProjectName-api-task"
                    "awslogs-region" = $Region
                    "awslogs-stream-prefix" = "ecs"
                }
            }
        }
    )
} | ConvertTo-Json -Depth 10

# タスク定義を登録
$taskDefArn = aws ecs register-task-definition --cli-input-json $taskDefJson --query 'taskDefinition.taskDefinitionArn' --output text

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to register task definition"
    exit 1
}

Write-Host "✅ Task definition registered: $taskDefArn" -ForegroundColor Green

# CodeDeploy デプロイメント設定
$deploymentConfig = @{
    applicationName = "$ProjectName-codedeploy-app"
    deploymentGroupName = "$ProjectName-deployment-group"
    revision = @{
        revisionType = "AppSpecContent"
        appSpecContent = @{
            content = @"
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
  - BeforeInstall: "echo 'Preparing for deployment'"
  - AfterInstall: "echo 'New task definition registered'"
  - AfterAllowTestTraffic: "echo 'Test traffic validation'"
  - BeforeAllowTraffic: "echo 'Switching to production traffic'"
  - AfterAllowTraffic: "echo 'Deployment completed successfully'"
"@
        }
    }
} | ConvertTo-Json -Depth 10

# デプロイメント実行
Write-Host "🔄 Starting CodeDeploy deployment..." -ForegroundColor Blue

$deploymentId = aws deploy create-deployment --cli-input-json $deploymentConfig --query 'deploymentId' --output text

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create deployment"
    exit 1
}

Write-Host "✅ Deployment started: $deploymentId" -ForegroundColor Green

# デプロイメント状況監視
Write-Host "⏳ Monitoring deployment progress..." -ForegroundColor Yellow

do {
    Start-Sleep -Seconds 30
    $status = aws deploy get-deployment --deployment-id $deploymentId --query 'deploymentInfo.status' --output text
    Write-Host "Status: $status" -ForegroundColor Cyan
} while ($status -eq "InProgress" -or $status -eq "Queued" -or $status -eq "Ready")

if ($status -eq "Succeeded") {
    Write-Host "🎉 Deployment completed successfully!" -ForegroundColor Green
    
    # ALB DNS名を表示
    $albDns = aws elbv2 describe-load-balancers --names "$ProjectName-alb" --query 'LoadBalancers[0].DNSName' --output text
    Write-Host "🌐 Application URL: http://$albDns" -ForegroundColor Yellow
    Write-Host "🧪 Test URL: http://$albDns`:8080" -ForegroundColor Yellow
} else {
    Write-Error "Deployment failed with status: $status"
    exit 1
}