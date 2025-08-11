# CodeDeploy Blue/Green Deployment Status Monitor
param(
    [string]$ProjectName = "nestjs-hannibal-3",
    [string]$Region = "ap-northeast-1"
)

$ErrorActionPreference = "Stop"

Write-Host "🔍 CodeDeploy Blue/Green Status Check" -ForegroundColor Green
Write-Host "Project: $ProjectName" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host ""

# CodeDeploy Application Status
Write-Host "🚀 CodeDeploy Application" -ForegroundColor Blue
$CodeDeployAppName = "$ProjectName-codedeploy-app"

try {
    $app = aws deploy get-application --application-name $CodeDeployAppName --region $Region | ConvertFrom-Json
    Write-Host "Application: $($app.application.applicationName)" -ForegroundColor White
    Write-Host "Compute Platform: $($app.application.computePlatform)" -ForegroundColor White
    Write-Host ""
} catch {
    Write-Host "CodeDeploy application not found: $CodeDeployAppName" -ForegroundColor Red
    exit 1
}

# Recent Deployments
Write-Host "📈 Recent Deployments" -ForegroundColor Blue
try {
    $deployments = aws deploy list-deployments --application-name $CodeDeployAppName --max-items 5 --region $Region | ConvertFrom-Json
    
    if ($deployments.deployments.Count -gt 0) {
        foreach ($deploymentId in $deployments.deployments) {
            $deployment = aws deploy get-deployment --deployment-id $deploymentId --region $Region | ConvertFrom-Json
            $info = $deployment.deploymentInfo
            
            $color = switch ($info.status) {
                "Succeeded" { "Green" }
                "Failed" { "Red" }
                "InProgress" { "Yellow" }
                "Queued" { "Cyan" }
                "Ready" { "Blue" }
                default { "White" }
            }
            
            Write-Host "  ID: $($info.deploymentId)" -ForegroundColor White
            Write-Host "  Status: $($info.status)" -ForegroundColor $color
            Write-Host "  Created: $($info.createTime)" -ForegroundColor Gray
            if ($info.completeTime) {
                Write-Host "  Completed: $($info.completeTime)" -ForegroundColor Gray
            }
            Write-Host ""
        }
    } else {
        Write-Host "  No deployments found" -ForegroundColor Gray
    }
} catch {
    Write-Host "  Error retrieving deployments" -ForegroundColor Red
}

# ECS Service Status
Write-Host "📊 ECS Service Status" -ForegroundColor Blue
$ClusterName = "$ProjectName-cluster"
$ServiceName = "$ProjectName-api-service"

$serviceStatus = aws ecs describe-services --cluster $ClusterName --services $ServiceName --region $Region --query 'services[0]' | ConvertFrom-Json

Write-Host "Service: $($serviceStatus.serviceName)" -ForegroundColor White
Write-Host "Status: $($serviceStatus.status)" -ForegroundColor $(if ($serviceStatus.status -eq "ACTIVE") { "Green" } else { "Red" })
Write-Host "Running Tasks: $($serviceStatus.runningCount)" -ForegroundColor White
Write-Host "Desired Tasks: $($serviceStatus.desiredCount)" -ForegroundColor White
Write-Host "Task Definition: $($serviceStatus.taskDefinition)" -ForegroundColor White
Write-Host "Deployment Controller: $($serviceStatus.deploymentController.type)" -ForegroundColor White
Write-Host ""

# Target Groups Health
Write-Host "🎯 Target Groups Health" -ForegroundColor Blue

# Blue Target Group
$blueTargets = aws elbv2 describe-target-health --target-group-arn $(aws elbv2 describe-target-groups --names "$ProjectName-blue-tg" --region $Region --query 'TargetGroups[0].TargetGroupArn' --output text) --region $Region | ConvertFrom-Json
Write-Host "Blue Target Group:" -ForegroundColor Cyan
foreach ($target in $blueTargets.TargetHealthDescriptions) {
    $color = switch ($target.TargetHealth.State) {
        "healthy" { "Green" }
        "unhealthy" { "Red" }
        "initial" { "Yellow" }
        "draining" { "Magenta" }
        default { "White" }
    }
    Write-Host "  Target: $($target.Target.Id):$($target.Target.Port) - $($target.TargetHealth.State)" -ForegroundColor $color
}

# Green Target Group
$greenTargets = aws elbv2 describe-target-health --target-group-arn $(aws elbv2 describe-target-groups --names "$ProjectName-green-tg" --region $Region --query 'TargetGroups[0].TargetGroupArn' --output text) --region $Region | ConvertFrom-Json
Write-Host "Green Target Group:" -ForegroundColor Cyan
foreach ($target in $greenTargets.TargetHealthDescriptions) {
    $color = switch ($target.TargetHealth.State) {
        "healthy" { "Green" }
        "unhealthy" { "Red" }
        "initial" { "Yellow" }
        "draining" { "Magenta" }
        default { "White" }
    }
    Write-Host "  Target: $($target.Target.Id):$($target.Target.Port) - $($target.TargetHealth.State)" -ForegroundColor $color
}
Write-Host ""

# ALB Listener Rules
Write-Host "🔀 ALB Listener Rules" -ForegroundColor Blue
$AlbName = "$ProjectName-alb"

# Production Listener (Port 80)
$prodListenerArn = aws elbv2 describe-listeners --load-balancer-arn $(aws elbv2 describe-load-balancers --names $AlbName --region $Region --query 'LoadBalancers[0].LoadBalancerArn' --output text) --region $Region --query 'Listeners[?Port==`80`].ListenerArn' --output text
$prodRules = aws elbv2 describe-rules --listener-arn $prodListenerArn --region $Region | ConvertFrom-Json

Write-Host "Production Listener (Port 80):" -ForegroundColor Cyan
foreach ($rule in $prodRules.Rules | Where-Object { $_.Priority -ne "default" }) {
    foreach ($action in $rule.Actions) {
        if ($action.Type -eq "forward" -and $action.ForwardConfig) {
            foreach ($tg in $action.ForwardConfig.TargetGroups) {
                $tgName = aws elbv2 describe-target-groups --target-group-arns $tg.TargetGroupArn --region $Region --query 'TargetGroups[0].TargetGroupName' --output text
                Write-Host "  $tgName - Weight: $($tg.Weight)%" -ForegroundColor $(if ($tg.Weight -gt 0) { "Green" } else { "Gray" })
            }
        }
    }
}

# Test Listener (Port 8080)
$testListenerArn = aws elbv2 describe-listeners --load-balancer-arn $(aws elbv2 describe-load-balancers --names $AlbName --region $Region --query 'LoadBalancers[0].LoadBalancerArn' --output text) --region $Region --query 'Listeners[?Port==`8080`].ListenerArn' --output text
if ($testListenerArn) {
    Write-Host "Test Listener (Port 8080):" -ForegroundColor Cyan
    $testRules = aws elbv2 describe-rules --listener-arn $testListenerArn --region $Region | ConvertFrom-Json
    foreach ($rule in $testRules.Rules | Where-Object { $_.Priority -ne "default" }) {
        foreach ($action in $rule.Actions) {
            if ($action.Type -eq "forward" -and $action.ForwardConfig) {
                foreach ($tg in $action.ForwardConfig.TargetGroups) {
                    $tgName = aws elbv2 describe-target-groups --target-group-arns $tg.TargetGroupArn --region $Region --query 'TargetGroups[0].TargetGroupName' --output text
                    Write-Host "  $tgName - Weight: $($tg.Weight)%" -ForegroundColor $(if ($tg.Weight -gt 0) { "Green" } else { "Gray" })
                }
            }
        }
    }
}
Write-Host ""

Write-Host "✅ Status check completed" -ForegroundColor Green

# Application URLs
$albDns = aws elbv2 describe-load-balancers --names $AlbName --region $Region --query 'LoadBalancers[0].DNSName' --output text
Write-Host "🌐 Application URLs:" -ForegroundColor Yellow
Write-Host "  Production: http://$albDns" -ForegroundColor White
Write-Host "  Test: http://$albDns:8080" -ForegroundColor White