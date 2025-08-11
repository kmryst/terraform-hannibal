# scripts/monitoring/blue-green-status.ps1
# Enterprise-level Blue/Green deployment status monitoring
# Based on Netflix/Airbnb/Spotify monitoring patterns

param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectName = "nestjs-hannibal-3",
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "ap-northeast-1",
    
    [Parameter(Mandatory=$false)]
    [switch]$Detailed
)

$ErrorActionPreference = "Stop"

Write-Host "🏢 Enterprise Blue/Green Deployment Status Monitor" -ForegroundColor Green
Write-Host "📊 Project: $ProjectName" -ForegroundColor Cyan
Write-Host "🌍 Region: $Region" -ForegroundColor Cyan

# ALB情報取得
Write-Host "`n🔍 Checking ALB Configuration..." -ForegroundColor Blue
$albInfo = aws elbv2 describe-load-balancers --names "$ProjectName-alb" --query 'LoadBalancers[0]' | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to retrieve ALB information"
    exit 1
}

Write-Host "✅ ALB DNS: $($albInfo.DNSName)" -ForegroundColor Green

# Target Groups情報取得
Write-Host "`n🎯 Checking Target Groups..." -ForegroundColor Blue
$blueTargetGroup = aws elbv2 describe-target-groups --names "$ProjectName-blue-tg" --query 'TargetGroups[0]' | ConvertFrom-Json
$greenTargetGroup = aws elbv2 describe-target-groups --names "$ProjectName-green-tg" --query 'TargetGroups[0]' | ConvertFrom-Json

# Blue Target Group Health
$blueHealth = aws elbv2 describe-target-health --target-group-arn $blueTargetGroup.TargetGroupArn --query 'TargetHealthDescriptions' | ConvertFrom-Json
$blueHealthyCount = ($blueHealth | Where-Object { $_.TargetHealth.State -eq "healthy" }).Count
$blueUnhealthyCount = ($blueHealth | Where-Object { $_.TargetHealth.State -ne "healthy" }).Count

# Green Target Group Health
$greenHealth = aws elbv2 describe-target-health --target-group-arn $greenTargetGroup.TargetGroupArn --query 'TargetHealthDescriptions' | ConvertFrom-Json
$greenHealthyCount = ($greenHealth | Where-Object { $_.TargetHealth.State -eq "healthy" }).Count
$greenUnhealthyCount = ($greenHealth | Where-Object { $_.TargetHealth.State -ne "healthy" }).Count

Write-Host "🔵 Blue Environment:" -ForegroundColor Blue
Write-Host "  - Healthy: $blueHealthyCount" -ForegroundColor Green
Write-Host "  - Unhealthy: $blueUnhealthyCount" -ForegroundColor Red

Write-Host "🟢 Green Environment:" -ForegroundColor Green
Write-Host "  - Healthy: $greenHealthyCount" -ForegroundColor Green
Write-Host "  - Unhealthy: $greenUnhealthyCount" -ForegroundColor Red

# Listener Rules情報取得
Write-Host "`n🎧 Checking Listener Rules..." -ForegroundColor Blue
$listeners = aws elbv2 describe-listeners --load-balancer-arn $albInfo.LoadBalancerArn --query 'Listeners' | ConvertFrom-Json

foreach ($listener in $listeners) {
    $rules = aws elbv2 describe-rules --listener-arn $listener.ListenerArn --query 'Rules' | ConvertFrom-Json
    
    Write-Host "📡 Listener Port $($listener.Port):" -ForegroundColor Cyan
    
    foreach ($rule in $rules) {
        if ($rule.Actions[0].Type -eq "forward" -and $rule.Actions[0].ForwardConfig) {
            $targetGroups = $rule.Actions[0].ForwardConfig.TargetGroups
            foreach ($tg in $targetGroups) {
                $tgName = (aws elbv2 describe-target-groups --target-group-arns $tg.TargetGroupArn --query 'TargetGroups[0].TargetGroupName' --output text)
                Write-Host "  - $tgName`: $($tg.Weight)%" -ForegroundColor Yellow
            }
        }
    }
}

# ECS Service情報取得
Write-Host "`n🐳 Checking ECS Service..." -ForegroundColor Blue
$ecsService = aws ecs describe-services --cluster "$ProjectName-cluster" --services "$ProjectName-api-service" --query 'services[0]' | ConvertFrom-Json

Write-Host "📊 ECS Service Status:" -ForegroundColor Cyan
Write-Host "  - Status: $($ecsService.status)" -ForegroundColor Green
Write-Host "  - Running Count: $($ecsService.runningCount)" -ForegroundColor Green
Write-Host "  - Desired Count: $($ecsService.desiredCount)" -ForegroundColor Green
Write-Host "  - Pending Count: $($ecsService.pendingCount)" -ForegroundColor Yellow

# 最新のCodeDeployデプロイメント情報
Write-Host "`n🚀 Checking Recent CodeDeploy Deployments..." -ForegroundColor Blue
$deployments = aws deploy list-deployments --application-name "$ProjectName-codedeploy-app" --deployment-group-name "$ProjectName-deployment-group" --max-items 5 --query 'deployments' | ConvertFrom-Json

if ($deployments.Count -gt 0) {
    $latestDeployment = aws deploy get-deployment --deployment-id $deployments[0] --query 'deploymentInfo' | ConvertFrom-Json
    
    Write-Host "📋 Latest Deployment:" -ForegroundColor Cyan
    Write-Host "  - ID: $($latestDeployment.deploymentId)" -ForegroundColor Yellow
    Write-Host "  - Status: $($latestDeployment.status)" -ForegroundColor Green
    Write-Host "  - Created: $($latestDeployment.createTime)" -ForegroundColor Gray
    
    if ($latestDeployment.completeTime) {
        Write-Host "  - Completed: $($latestDeployment.completeTime)" -ForegroundColor Gray
    }
}

# 詳細情報表示
if ($Detailed) {
    Write-Host "`n📈 Detailed Health Information..." -ForegroundColor Blue
    
    Write-Host "`n🔵 Blue Target Details:" -ForegroundColor Blue
    foreach ($target in $blueHealth) {
        Write-Host "  - Target: $($target.Target.Id):$($target.Target.Port)" -ForegroundColor Gray
        Write-Host "    State: $($target.TargetHealth.State)" -ForegroundColor $(if ($target.TargetHealth.State -eq "healthy") { "Green" } else { "Red" })
        if ($target.TargetHealth.Description) {
            Write-Host "    Description: $($target.TargetHealth.Description)" -ForegroundColor Gray
        }
    }
    
    Write-Host "`n🟢 Green Target Details:" -ForegroundColor Green
    foreach ($target in $greenHealth) {
        Write-Host "  - Target: $($target.Target.Id):$($target.Target.Port)" -ForegroundColor Gray
        Write-Host "    State: $($target.TargetHealth.State)" -ForegroundColor $(if ($target.TargetHealth.State -eq "healthy") { "Green" } else { "Red" })
        if ($target.TargetHealth.Description) {
            Write-Host "    Description: $($target.TargetHealth.Description)" -ForegroundColor Gray
        }
    }
}

# サマリー表示
Write-Host "`n📊 Environment Summary:" -ForegroundColor White
Write-Host "🌐 Production URL: http://$($albInfo.DNSName)" -ForegroundColor Yellow
Write-Host "🧪 Test URL: http://$($albInfo.DNSName):8080" -ForegroundColor Yellow

$activeEnvironment = if ($blueHealthyCount -gt 0 -and $greenHealthyCount -eq 0) { "Blue" } 
                    elseif ($greenHealthyCount -gt 0 -and $blueHealthyCount -eq 0) { "Green" }
                    elseif ($blueHealthyCount -gt 0 -and $greenHealthyCount -gt 0) { "Both (Deployment in progress)" }
                    else { "None (Service Down)" }

Write-Host "🎯 Active Environment: $activeEnvironment" -ForegroundColor Cyan

Write-Host "`n🏁 Blue/Green status check completed" -ForegroundColor Green