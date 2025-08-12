# Enterprise-level Blue/Green Deployment Monitor
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
    [int]$MonitorInterval = 15,
    
    [Parameter(Mandatory=$false)]
    [switch]$Detailed
)

$ErrorActionPreference = "Stop"

# --- Enterprise Header ---
Write-Host "🏢 Enterprise Blue/Green Deployment Monitor" -ForegroundColor Green
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

function Get-TrafficDistribution {
    Write-Host "🔀 Traffic Distribution" -ForegroundColor Blue
    
    try {
        $albArn = aws elbv2 describe-load-balancers --names "$ProjectName-alb" --region $Region --query 'LoadBalancers[0].LoadBalancerArn' --output text
        $prodListenerArn = aws elbv2 describe-listeners --load-balancer-arn $albArn --region $Region --query 'Listeners[?Port==`80`].ListenerArn' --output text
        
        $rules = aws elbv2 describe-rules --listener-arn $prodListenerArn --region $Region | ConvertFrom-Json
        
        Write-Host "Production Listener (Port 80):" -ForegroundColor Yellow
        foreach ($rule in $rules.Rules | Where-Object { $_.Priority -ne "default" }) {
            foreach ($action in $rule.Actions) {
                if ($action.Type -eq "forward" -and $action.ForwardConfig) {
                    foreach ($tg in $action.ForwardConfig.TargetGroups) {
                        $tgName = aws elbv2 describe-target-groups --target-group-arns $tg.TargetGroupArn --region $Region --query 'TargetGroups[0].TargetGroupName' --output text
                        $color = if ($tg.Weight -gt 0) { "Green" } else { "Gray" }
                        Write-Host "  $tgName - Weight: $($tg.Weight)%" -ForegroundColor $color
                    }
                }
            }
        }
        
        # Application URLs
        $albDns = aws elbv2 describe-load-balancers --names "$ProjectName-alb" --region $Region --query 'LoadBalancers[0].DNSName' --output text
        Write-Host "`n🌐 Application URLs:" -ForegroundColor Yellow
        Write-Host "  Production: http://$albDns" -ForegroundColor White
        Write-Host "  Test: http://$albDns:8080" -ForegroundColor White
        
    } catch {
        Write-Host "❌ ALB not found" -ForegroundColor Red
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
        Get-ECSServiceStatus
        Get-EnvironmentHealth
        Get-TrafficDistribution
        Write-Host "✅ Status check completed" -ForegroundColor Green
    }
    
    "Monitor" {
        Write-Host "🔄 Starting real-time monitoring (Ctrl+C to stop)" -ForegroundColor Yellow
        Write-Host "Update interval: $MonitorInterval seconds" -ForegroundColor Gray
        Write-Host ""
        
        $iteration = 1
        while ($true) {
            Write-Host "==================== UPDATE #$iteration - $(Get-Date) ====================" -ForegroundColor Green
            
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
        Get-EnvironmentHealth
        Get-TrafficDistribution
        
        Write-Host "📊 Deployment Summary:" -ForegroundColor White
        Write-Host "✅ Blue/Green deployment monitoring completed" -ForegroundColor Green
    }
}