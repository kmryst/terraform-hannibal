# Enterprise-level Blue/Green & Canary Deployment Monitor
# Based on Netflix/Airbnb/Spotify monitoring patterns
# AWS Certified Professional/Specialty standard implementation

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("Status", "Monitor", "Summary")]
    [string]$Mode = "Status",
    
    [Parameter(Mandatory=$false)]
    [string]$ProjectName = "nestjs-hannibal-3",
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "ap-northeast-1",

    [Parameter(Mandatory=$false)]
    [string]$ApiDomainName = "api.hamilcar-hannibal.click",
    
    [Parameter(Mandatory=$false)]
    [int]$MonitorInterval = 15,
    
    [Parameter(Mandatory=$false)]
    [switch]$Detailed
)

$ErrorActionPreference = "Stop"

# --- Enterprise Header ---
Write-Host "🏢 Enterprise Blue/Green & Canary Deployment Monitor" -ForegroundColor Green
Write-Host "📊 Project: $ProjectName | Region: $Region | Mode: $Mode" -ForegroundColor Cyan
Write-Host ""

# --- Core Functions ---
function Get-CodeDeployStatus {
    Write-Host "🚀 CodeDeploy Application Status" -ForegroundColor Blue
    
    try {
        $app = aws deploy get-application --application-name "$ProjectName-app" --region $Region | ConvertFrom-Json
        Write-Host "✅ Application: $($app.application.applicationName)" -ForegroundColor Green
        
        # Recent deployments
        $deployments = aws deploy list-deployments --application-name "$ProjectName-app" --max-items 5 --region $Region | ConvertFrom-Json
        
        if ($deployments.deployments.Count -gt 0) {
            Write-Host "📈 Recent Deployments:" -ForegroundColor Yellow
            foreach ($deploymentId in $deployments.deployments) {
                $deployment = aws deploy get-deployment --deployment-id $deploymentId --region $Region | ConvertFrom-Json
                $info = $deployment.deploymentInfo
                
                $color = switch ($info.status) {
                    "Succeeded" { "Green" }
                    "Failed" { "Red" }
                    "InProgress" { "Yellow" }
                    default { "White" }
                }
                
                Write-Host "  $($info.deploymentId): $($info.status)" -ForegroundColor $color
            }
        }
    } catch {
        Write-Host "❌ CodeDeploy application not found" -ForegroundColor Red
    }
    Write-Host ""
}

function Get-EnvironmentHealth {
    Write-Host "🎯 Environment Health Status" -ForegroundColor Blue
    
    try {
        # Blue Environment
        $blueHealth = aws elbv2 describe-target-health --target-group-arn $(aws elbv2 describe-target-groups --names "$ProjectName-blue-tg" --region $Region --query 'TargetGroups[0].TargetGroupArn' --output text) --region $Region | ConvertFrom-Json
        $blueHealthyCount = ($blueHealth.TargetHealthDescriptions | Where-Object { $_.TargetHealth.State -eq "healthy" }).Count
        
        # Green Environment
        $greenHealth = aws elbv2 describe-target-health --target-group-arn $(aws elbv2 describe-target-groups --names "$ProjectName-green-tg" --region $Region --query 'TargetGroups[0].TargetGroupArn' --output text) --region $Region | ConvertFrom-Json
        $greenHealthyCount = ($greenHealth.TargetHealthDescriptions | Where-Object { $_.TargetHealth.State -eq "healthy" }).Count
        
        Write-Host "🔵 Blue Environment: $blueHealthyCount healthy" -ForegroundColor Blue
        Write-Host "🟢 Green Environment: $greenHealthyCount healthy" -ForegroundColor Green
        
        # Active Environment Detection
        $activeEnvironment = if ($blueHealthyCount -gt 0 -and $greenHealthyCount -eq 0) { "Blue" } 
                            elseif ($greenHealthyCount -gt 0 -and $blueHealthyCount -eq 0) { "Green" }
                            elseif ($blueHealthyCount -gt 0 -and $greenHealthyCount -gt 0) { "Both (Deployment in progress)" }
                            else { "None (Service Down)" }
        
        Write-Host "🎯 Active Environment: $activeEnvironment" -ForegroundColor Cyan
        
        if ($Detailed) {
            Write-Host "`n📋 Detailed Target Health:" -ForegroundColor Yellow
            Write-Host "Blue Targets:" -ForegroundColor Blue
            foreach ($target in $blueHealth.TargetHealthDescriptions) {
                $color = if ($target.TargetHealth.State -eq "healthy") { "Green" } else { "Red" }
                Write-Host "  $($target.Target.Id):$($target.Target.Port) - $($target.TargetHealth.State)" -ForegroundColor $color
            }
            Write-Host "Green Targets:" -ForegroundColor Green
            foreach ($target in $greenHealth.TargetHealthDescriptions) {
                $color = if ($target.TargetHealth.State -eq "healthy") { "Green" } else { "Red" }
                Write-Host "  $($target.Target.Id):$($target.Target.Port) - $($target.TargetHealth.State)" -ForegroundColor $color
            }
        }
        
    } catch {
        Write-Host "❌ Target groups not found" -ForegroundColor Red
    }
    Write-Host ""
}

function Get-CodeDeployDeploymentStatus {
    Write-Host "🚀 Active CodeDeploy Status" -ForegroundColor Blue
    
    try {
        $deployments = aws deploy list-deployments --application-name "$ProjectName-app" --deployment-group-name "$ProjectName-dg" --include-only-statuses "InProgress" "Queued" "Ready" --region $Region | ConvertFrom-Json
        
        if ($deployments.deployments.Count -gt 0) {
            foreach ($deploymentId in $deployments.deployments) {
                $deployment = aws deploy get-deployment --deployment-id $deploymentId --region $Region | ConvertFrom-Json
                $info = $deployment.deploymentInfo
                
                Write-Host "📋 Deployment: $($info.deploymentId)" -ForegroundColor White
                Write-Host "   Status: $($info.status)" -ForegroundColor Yellow
                Write-Host "   Config: $($info.deploymentConfigName)" -ForegroundColor Gray
                Write-Host "   Started: $($info.createTime)" -ForegroundColor Gray
                
                if ($info.status -eq "InProgress") {
                    # Canaryデプロイの場合は段階表示
                if ($info.deploymentConfigName -like "*Canary*") {
                    Write-Host "   🔍 Canary deployment in progress..." -ForegroundColor Yellow
                    Write-Host "   📊 Phase: 10% traffic → monitoring → 100% traffic" -ForegroundColor Cyan
                } else {
                    Write-Host "   ⏳ Deployment in progress..." -ForegroundColor Yellow
                }
                }
            }
        } else {
            Write-Host "✅ No active deployments" -ForegroundColor Green
        }
    } catch {
        Write-Host "❌ CodeDeploy status unavailable" -ForegroundColor Red
    }
    Write-Host ""
}

function Get-TrafficDistribution {
    Write-Host "🔀 Traffic Distribution" -ForegroundColor Blue
    
    try {
        $albArn = aws elbv2 describe-load-balancers --names "$ProjectName-alb" --region $Region --query 'LoadBalancers[0].LoadBalancerArn' --output text
        $prodListenerArn = aws elbv2 describe-listeners --load-balancer-arn $albArn --region $Region --query 'Listeners[?Port==`443`].ListenerArn' --output text
        
        $rules = aws elbv2 describe-rules --listener-arn $prodListenerArn --region $Region | ConvertFrom-Json
        
        Write-Host "Production Listener (Port 443 HTTPS):" -ForegroundColor Yellow
        
        $totalWeight = 0
        $blueWeight = 0
        $greenWeight = 0
        
        foreach ($rule in $rules.Rules | Where-Object { $_.Priority -ne "default" }) {
            foreach ($action in $rule.Actions) {
                if ($action.Type -eq "forward") {
                    if ($action.ForwardConfig -and $action.ForwardConfig.TargetGroups) {
                        # Multiple target groups (Blue/Green or Canary)
                        foreach ($tg in $action.ForwardConfig.TargetGroups) {
                            $tgName = aws elbv2 describe-target-groups --target-group-arns $tg.TargetGroupArn --region $Region --query 'TargetGroups[0].TargetGroupName' --output text
                            # AWS ALB Weight=1 means 100% when single target group
                            $weight = if ($action.ForwardConfig.TargetGroups.Count -eq 1 -and $tg.Weight -eq 1) { 100 } else { $tg.Weight }
                            $totalWeight += $weight
                            
                            if ($tgName -like "*blue*") { $blueWeight = $weight }
                            if ($tgName -like "*green*") { $greenWeight = $weight }
                            
                            # Color based on environment type, not weight
                            $color = if ($tgName -like "*blue*") { "Blue" } 
                                    elseif ($tgName -like "*green*") { "Green" } 
                                    elseif ($weight -gt 0) { "White" } 
                                    else { "Gray" }
                            Write-Host "  $tgName - Weight: $weight%" -ForegroundColor $color
                        }
                    } elseif ($action.TargetGroupArn) {
                        # Single target group (100% traffic)
                        $tgName = aws elbv2 describe-target-groups --target-group-arns $action.TargetGroupArn --region $Region --query 'TargetGroups[0].TargetGroupName' --output text
                        $weight = 100
                        $totalWeight = 100
                        
                        if ($tgName -like "*blue*") { $blueWeight = 100 }
                        if ($tgName -like "*green*") { $greenWeight = 100 }
                        
                        # Color based on environment type
                        $color = if ($tgName -like "*blue*") { "Blue" } else { "Green" }
                        Write-Host "  $tgName - Weight: 100%" -ForegroundColor $color
                    }
                }
            }
        }
        
        # Deployment Type Detection
        if ($blueWeight -gt 0 -and $greenWeight -gt 0) {
            if ($blueWeight -eq $greenWeight) {
                Write-Host "📊 Deployment Type: A/B Testing (50/50)" -ForegroundColor Cyan
            } elseif ($blueWeight -lt 10 -or $greenWeight -lt 10) {
                Write-Host "📊 Deployment Type: Canary ($blueWeight% Blue, $greenWeight% Green)" -ForegroundColor Yellow
            } else {
                Write-Host "📊 Deployment Type: Linear ($blueWeight% Blue, $greenWeight% Green)" -ForegroundColor Magenta
            }
        } elseif ($blueWeight -eq 100) {
            Write-Host "📊 Deployment Type: Blue Environment (100%)" -ForegroundColor Blue
        } elseif ($greenWeight -eq 100) {
            Write-Host "📊 Deployment Type: Green Environment (100%)" -ForegroundColor Green
        }
        
        # Application URLs
        Write-Host "`n🌐 Application URLs:" -ForegroundColor Yellow
        try {
            $albDns = aws elbv2 describe-load-balancers --names "$ProjectName-alb" --region $Region --query 'LoadBalancers[0].DNSName' --output text 2>$null
            if ($albDns -and $albDns -ne "None" -and $albDns -ne "") {
                Write-Host "  Production: https://$ApiDomainName" -ForegroundColor White
                Write-Host "  Test: https://$($ApiDomainName):8080" -ForegroundColor White
            } else {
                Write-Host "  Production: https://$ApiDomainName" -ForegroundColor Red
                Write-Host "  Test: https://$($ApiDomainName):8080" -ForegroundColor Red
            }
        } catch {
            Write-Host "  Production: https://$ApiDomainName" -ForegroundColor Red
            Write-Host "  Test: https://$($ApiDomainName):8080" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "❌ ALB not found" -ForegroundColor Red
    }
    Write-Host ""
}

function Get-CanaryAlarmStatus {
    Write-Host "🚨 Canary Deployment Alarms" -ForegroundColor Blue
    
    try {
        # カナリア用アラーム状態確認
        $errorAlarm = aws cloudwatch describe-alarms --alarm-names "$ProjectName-canary-error-rate" --region $Region --query 'MetricAlarms[0].StateValue' --output text 2>$null
        $responseAlarm = aws cloudwatch describe-alarms --alarm-names "$ProjectName-canary-response-time" --region $Region --query 'MetricAlarms[0].StateValue' --output text 2>$null
        
        if ($errorAlarm -and $errorAlarm -ne "None") {
            $color = switch ($errorAlarm) {
                "OK" { "Green" }
                "ALARM" { "Red" }
                "INSUFFICIENT_DATA" { "Yellow" }
                default { "Gray" }
            }
            Write-Host "  Error Rate Alarm: $errorAlarm" -ForegroundColor $color
        }
        
        if ($responseAlarm -and $responseAlarm -ne "None") {
            $color = switch ($responseAlarm) {
                "OK" { "Green" }
                "ALARM" { "Red" }
                "INSUFFICIENT_DATA" { "Yellow" }
                default { "Gray" }
            }
            Write-Host "  Response Time Alarm: $responseAlarm" -ForegroundColor $color
        }
        
        if (-not $errorAlarm -and -not $responseAlarm) {
            Write-Host "  ⚠️ No canary alarms configured" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "  ⚠️ Alarm status unavailable" -ForegroundColor Yellow
    }
    Write-Host ""
}

function Get-ECSServiceStatus {
    Write-Host "🐳 ECS Service Status" -ForegroundColor Blue
    
    try {
        $service = aws ecs describe-services --cluster "$ProjectName-cluster" --services "$ProjectName-api-service" --region $Region --query 'services[0]' | ConvertFrom-Json
        
        Write-Host "Service: $($service.serviceName)" -ForegroundColor White
        Write-Host "Status: $($service.status)" -ForegroundColor $(if ($service.status -eq "ACTIVE") { "Green" } else { "Red" })
        Write-Host "Running: $($service.runningCount) / Desired: $($service.desiredCount)" -ForegroundColor White
        Write-Host "Deployment Controller: $($service.deploymentController.type)" -ForegroundColor White
        
    } catch {
        Write-Host "❌ ECS service not found" -ForegroundColor Red
    }
    Write-Host ""
}

# --- Mode Execution ---
switch ($Mode) {
    "Status" {
        Get-CodeDeployStatus
        Get-CodeDeployDeploymentStatus
        Get-ECSServiceStatus
        Get-EnvironmentHealth
        Get-TrafficDistribution
        # CloudWatchアラーム状態確認
        Get-CanaryAlarmStatus
        Write-Host "✅ Status check completed" -ForegroundColor Green
    }
    
    "Monitor" {
        Write-Host "🔄 Starting real-time monitoring (Ctrl+C to stop)" -ForegroundColor Yellow
        Write-Host "Update interval: $MonitorInterval seconds" -ForegroundColor Gray
        Write-Host ""
        
        $iteration = 1
        while ($true) {
            Write-Host "==================== UPDATE #$iteration - $(Get-Date) ====================" -ForegroundColor Green
            
            Get-CodeDeployDeploymentStatus
            Get-EnvironmentHealth
            Get-TrafficDistribution
            
            # ECS Deployments
            try {
                Write-Host "📊 ECS Deployments:" -ForegroundColor Blue
                aws ecs describe-services --cluster "$ProjectName-cluster" --services "$ProjectName-api-service" --query 'services[0].deployments[*].{Status:status,TaskDef:taskDefinition,Running:runningCount,Desired:desiredCount}' --output table --region $Region
            } catch {
                Write-Host "❌ ECS service not found" -ForegroundColor Red
            }
            
            Write-Host "`n--- Next update in $MonitorInterval seconds ---" -ForegroundColor Gray
            $iteration++
            Start-Sleep $MonitorInterval
        }
    }
    
    "Summary" {
        Get-CodeDeployStatus
        Get-CodeDeployDeploymentStatus
        Get-EnvironmentHealth
        Get-TrafficDistribution
        
        Write-Host "📊 Deployment Summary:" -ForegroundColor White
        Write-Host "✅ Blue/Green deployment monitoring completed" -ForegroundColor Green
    }
}
