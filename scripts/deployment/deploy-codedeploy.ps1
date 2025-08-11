# scripts/deployment/deploy-codedeploy.ps1
# AWS CodeDeploy Blue/Green ECS Deployment Script
# Based on AWS Official Documentation and Best Practices

param(
    [Parameter(Mandatory=$true)]
    [string]$ImageTag,
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [int]$TimeoutMinutes = 30
)

$ErrorActionPreference = "Stop"

# Configuration
$ProjectName = "nestjs-hannibal-3"
$Region = "ap-northeast-1"
$AccountId = "258632448142"
$EcrRepository = "$AccountId.dkr.ecr.$Region.amazonaws.com/$ProjectName"

Write-Host "🚀 Starting AWS CodeDeploy Blue/Green ECS Deployment" -ForegroundColor Green
Write-Host "📦 Image: $EcrRepository`:$ImageTag" -ForegroundColor Yellow
Write-Host "🌍 Environment: $Environment" -ForegroundColor Cyan
Write-Host "⚙️  Config: CodeDeployDefault.ECSAllAtOnce" -ForegroundColor Magenta

# Step 1: Terraform Apply
Write-Host "`n📋 Step 1: Applying Terraform configuration..." -ForegroundColor Blue
try {
    Set-Location "terraform/backend"
    
    $terraformPlan = terraform plan -var="environment=$Environment" -out="tfplan"
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform plan failed"
    }
    
    $terraformApply = terraform apply -auto-approve "tfplan"
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform apply failed"
    }
    
    Write-Host "✅ Terraform apply completed successfully" -ForegroundColor Green
    
    Set-Location "../.."
} catch {
    Write-Error "❌ Terraform operation failed: $_"
    exit 1
}

# Step 2: Get Current Task Definition
Write-Host "`n📋 Step 2: Retrieving current task definition..." -ForegroundColor Blue
try {
    $currentTaskDef = aws ecs describe-task-definition --task-definition "$ProjectName-api-task" --query 'taskDefinition' | ConvertFrom-Json
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve current task definition"
    }
    
    Write-Host "✅ Current task definition retrieved" -ForegroundColor Green
} catch {
    Write-Error "❌ Failed to get task definition: $_"
    exit 1
}

# Step 3: Create New Task Definition
Write-Host "`n🔧 Step 3: Creating new task definition..." -ForegroundColor Blue
try {
    # Update container image
    $currentTaskDef.containerDefinitions[0].image = "$EcrRepository`:$ImageTag"
    
    # Remove read-only fields
    $newTaskDef = $currentTaskDef | Select-Object -Property * -ExcludeProperty taskDefinitionArn, revision, status, requiresAttributes, placementConstraints, compatibilities, registeredAt, registeredBy
    
    $taskDefJson = $newTaskDef | ConvertTo-Json -Depth 10
    
    # Register new task definition
    $newTaskDefArn = aws ecs register-task-definition --cli-input-json $taskDefJson --query 'taskDefinition.taskDefinitionArn' --output text
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to register new task definition"
    }
    
    Write-Host "✅ New task definition registered: $newTaskDefArn" -ForegroundColor Green
} catch {
    Write-Error "❌ Failed to create task definition: $_"
    exit 1
}

# Step 4: Create AppSpec
Write-Host "`n📝 Step 4: Creating AppSpec for CodeDeploy..." -ForegroundColor Blue
$appSpecContent = @{
    version = "0.0"
    Resources = @(
        @{
            TargetService = @{
                Type = "AWS::ECS::Service"
                Properties = @{
                    TaskDefinition = $newTaskDefArn
                    LoadBalancerInfo = @{
                        ContainerName = "$ProjectName-container"
                        ContainerPort = 3000
                    }
                    PlatformVersion = "LATEST"
                }
            }
        }
    )
} | ConvertTo-Json -Depth 10

Write-Host "✅ AppSpec created" -ForegroundColor Green

# Step 5: Execute CodeDeploy Deployment
Write-Host "`n🚀 Step 5: Starting CodeDeploy deployment..." -ForegroundColor Blue
try {
    $deploymentId = aws deploy create-deployment `
        --application-name "$ProjectName-codedeploy-app" `
        --deployment-group-name "$ProjectName-deployment-group" `
        --deployment-config-name "CodeDeployDefault.ECSAllAtOnce" `
        --revision "revisionType=AppSpecContent,appSpecContent={content='$($appSpecContent -replace '"', '\"')'}" `
        --query 'deploymentId' --output text
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create CodeDeploy deployment"
    }
    
    Write-Host "✅ CodeDeploy deployment initiated: $deploymentId" -ForegroundColor Green
} catch {
    Write-Error "❌ Failed to start deployment: $_"
    exit 1
}

# Step 6: Monitor Deployment
Write-Host "`n⏳ Step 6: Monitoring deployment progress..." -ForegroundColor Yellow
$startTime = Get-Date
$timeoutTime = $startTime.AddMinutes($TimeoutMinutes)

try {
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
            throw "Deployment timeout"
        }
        
    } while ($status -eq "InProgress" -or $status -eq "Queued" -or $status -eq "Ready")
    
    if ($status -eq "Succeeded") {
        $totalTime = [math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)
        Write-Host "`n🎉 CodeDeploy Blue/Green deployment completed successfully!" -ForegroundColor Green
        Write-Host "📊 Total deployment time: $totalTime minutes" -ForegroundColor Cyan
        
        # Get ALB information
        $albDns = aws elbv2 describe-load-balancers --names "$ProjectName-alb" --query 'LoadBalancers[0].DNSName' --output text
        Write-Host "🌐 Production URL: http://$albDns" -ForegroundColor Yellow
        Write-Host "🧪 Test URL: http://$albDns`:8080" -ForegroundColor Yellow
        Write-Host "📈 CloudWatch Logs: /aws/codedeploy/$ProjectName" -ForegroundColor Magenta
        
        # Deployment Summary
        Write-Host "`n📋 Deployment Summary:" -ForegroundColor White
        Write-Host "  - Image: $EcrRepository`:$ImageTag" -ForegroundColor Gray
        Write-Host "  - Environment: $Environment" -ForegroundColor Gray
        Write-Host "  - Duration: $totalTime minutes" -ForegroundColor Gray
        Write-Host "  - Deployment ID: $deploymentId" -ForegroundColor Gray
        
    } else {
        Write-Host "`n❌ CodeDeploy deployment failed with status: $status" -ForegroundColor Red
        
        # Error Information
        if ($deploymentInfo.errorInformation) {
            Write-Host "🔍 Error Information:" -ForegroundColor Red
            Write-Host "  Code: $($deploymentInfo.errorInformation.code)" -ForegroundColor Gray
            Write-Host "  Message: $($deploymentInfo.errorInformation.message)" -ForegroundColor Gray
        }
        
        throw "Deployment failed with status: $status"
    }
    
} catch {
    Write-Error "❌ Deployment monitoring failed: $_"
    exit 1
}

Write-Host "`n🏁 AWS CodeDeploy Blue/Green ECS deployment process completed" -ForegroundColor Green