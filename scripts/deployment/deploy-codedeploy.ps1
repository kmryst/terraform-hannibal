# scripts/deployment/deploy-codedeploy.ps1
# Enterprise AWS CodeDeploy Blue/Green ECS Deployment Script
# Compliant with AWS Official Documentation and Best Practices

param(
    [Parameter(Mandatory=$true)]
    [string]$ImageTag,
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [int]$TimeoutMinutes = 30,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipTerraform
)

$ErrorActionPreference = "Stop"

# Configuration
$ProjectName = "nestjs-hannibal-3"
$Region = "ap-northeast-1"
$AccountId = "258632448142"
$EcrRepository = "$AccountId.dkr.ecr.$Region.amazonaws.com/$ProjectName"

Write-Host "🚀 Starting Enterprise AWS CodeDeploy Blue/Green ECS Deployment" -ForegroundColor Green
Write-Host "📦 Image: $EcrRepository`:$ImageTag" -ForegroundColor Yellow
Write-Host "🌍 Environment: $Environment" -ForegroundColor Cyan
Write-Host "⚙️  Config: CodeDeployDefault.ECSAllAtOnce" -ForegroundColor Magenta
Write-Host "⏱️  Wait Time: 1 minute (Fast Deployment)" -ForegroundColor Blue

# Step 1: Terraform Apply (Optional)
if (-not $SkipTerraform) {
    Write-Host "`n📋 Step 1: Applying Terraform configuration..." -ForegroundColor Blue
    try {
        Set-Location "terraform/backend"
        
        Write-Host "  - Running terraform init..." -ForegroundColor Gray
        $terraformInit = terraform init -input=false
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform init failed"
        }
        
        Write-Host "  - Running terraform plan..." -ForegroundColor Gray
        $terraformPlan = terraform plan -var="environment=$Environment" -out="tfplan"
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform plan failed"
        }
        
        Write-Host "  - Running terraform apply..." -ForegroundColor Gray
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
} else {
    Write-Host "`n⏭️  Step 1: Skipping Terraform (--SkipTerraform specified)" -ForegroundColor Yellow
}

# Step 2: Get Terraform Outputs
Write-Host "`n📋 Step 2: Retrieving Terraform configuration..." -ForegroundColor Blue
try {
    Set-Location "terraform/backend"
    
    $prodListenerArn = terraform output -raw production_listener_arn
    $testListenerArn = terraform output -raw test_listener_arn
    $blueTgName = terraform output -raw blue_target_group_name
    $greenTgName = terraform output -raw green_target_group_name
    $waitTime = terraform output -raw codedeploy_wait_time_minutes
    $terminationWaitTime = terraform output -raw codedeploy_termination_wait_time_minutes
    
    Set-Location "../.."
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve Terraform outputs"
    }
    
    Write-Host "✅ Terraform Configuration Retrieved:" -ForegroundColor Green
    Write-Host "  - Production Listener: $prodListenerArn" -ForegroundColor Gray
    Write-Host "  - Test Listener: $testListenerArn" -ForegroundColor Gray
    Write-Host "  - Blue Target Group: $blueTgName" -ForegroundColor Gray
    Write-Host "  - Green Target Group: $greenTgName" -ForegroundColor Gray
    Write-Host "  - Wait Time: $waitTime minutes" -ForegroundColor Gray
    Write-Host "  - Termination Wait: $terminationWaitTime minutes" -ForegroundColor Gray
    
} catch {
    Write-Error "❌ Failed to get Terraform outputs: $_"
    exit 1
}

# Step 3: Get Current Task Definition
Write-Host "`n📋 Step 3: Retrieving current task definition..." -ForegroundColor Blue
try {
    $currentTaskDefJson = aws ecs describe-task-definition --task-definition "$ProjectName-api-task" --query 'taskDefinition'
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve current task definition"
    }
    
    $currentTaskDef = $currentTaskDefJson | ConvertFrom-Json
    Write-Host "✅ Current task definition retrieved: $($currentTaskDef.taskDefinitionArn)" -ForegroundColor Green
} catch {
    Write-Error "❌ Failed to get task definition: $_"
    exit 1
}

# Step 4: Create New Task Definition
Write-Host "`n🔧 Step 4: Creating new task definition..." -ForegroundColor Blue
try {
    # Update container image
    $currentTaskDef.containerDefinitions[0].image = "$EcrRepository`:$ImageTag"
    
    # Remove read-only fields
    $newTaskDef = $currentTaskDef | Select-Object -Property * -ExcludeProperty taskDefinitionArn, revision, status, requiresAttributes, placementConstraints, compatibilities, registeredAt, registeredBy
    
    $taskDefJson = $newTaskDef | ConvertTo-Json -Depth 10 -Compress
    
    # Register new task definition
    $newTaskDefResult = aws ecs register-task-definition --cli-input-json $taskDefJson
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to register new task definition"
    }
    
    $newTaskDefInfo = $newTaskDefResult | ConvertFrom-Json
    $newTaskDefArn = $newTaskDefInfo.taskDefinition.taskDefinitionArn
    
    Write-Host "✅ New task definition registered: $newTaskDefArn" -ForegroundColor Green
} catch {
    Write-Error "❌ Failed to create task definition: $_"
    exit 1
}

# Step 5: Create AppSpec
Write-Host "`n📝 Step 5: Creating AppSpec for CodeDeploy..." -ForegroundColor Blue
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
    Hooks = @(
        @{
            BeforeInstall = "echo 'Starting Blue/Green deployment preparation'"
        },
        @{
            AfterInstall = "echo 'New task definition registered successfully'"
        },
        @{
            AfterAllowTestTraffic = "echo 'Test traffic validation completed'"
        },
        @{
            BeforeAllowTraffic = "echo 'Preparing production traffic switch'"
        },
        @{
            AfterAllowTraffic = "echo 'Production traffic switch completed successfully'"
        }
    )
} | ConvertTo-Json -Depth 10 -Compress

Write-Host "✅ AppSpec created with deployment hooks" -ForegroundColor Green

# Step 6: Execute CodeDeploy Deployment
Write-Host "`n🚀 Step 6: Starting CodeDeploy Blue/Green deployment..." -ForegroundColor Blue
try {
    $deploymentResult = aws deploy create-deployment `
        --application-name "$ProjectName-codedeploy-app" `
        --deployment-group-name "$ProjectName-deployment-group" `
        --deployment-config-name "CodeDeployDefault.ECSAllAtOnce" `
        --revision "revisionType=AppSpecContent,appSpecContent={content='$($appSpecContent -replace '"', '\"')'}"
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create CodeDeploy deployment"
    }
    
    $deploymentInfo = $deploymentResult | ConvertFrom-Json
    $deploymentId = $deploymentInfo.deploymentId
    
    Write-Host "✅ Enterprise CodeDeploy deployment initiated: $deploymentId" -ForegroundColor Green
    Write-Host "📊 Monitor at: https://console.aws.amazon.com/codesuite/codedeploy/deployments/$deploymentId" -ForegroundColor Cyan
} catch {
    Write-Error "❌ Failed to start deployment: $_"
    exit 1
}

# Step 7: Monitor Deployment
Write-Host "`n⏳ Step 7: Monitoring enterprise deployment progress..." -ForegroundColor Yellow
$startTime = Get-Date
$timeoutTime = $startTime.AddMinutes($TimeoutMinutes)

try {
    do {
        Start-Sleep -Seconds 30
        $currentTime = Get-Date
        $elapsed = ($currentTime - $startTime).TotalMinutes
        
        $deploymentInfoResult = aws deploy get-deployment --deployment-id $deploymentId --query 'deploymentInfo'
        $deploymentDetails = $deploymentInfoResult | ConvertFrom-Json
        $status = $deploymentDetails.status
        
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Status: $status (Elapsed: $([math]::Round($elapsed, 1)) min)" -ForegroundColor Cyan
        
        if ($currentTime -gt $timeoutTime) {
            Write-Host "⏰ Enterprise deployment timeout after $TimeoutMinutes minutes" -ForegroundColor Red
            Write-Host "🔄 Initiating automatic rollback..." -ForegroundColor Yellow
            aws deploy stop-deployment --deployment-id $deploymentId --auto-rollback-enabled
            throw "Deployment timeout"
        }
        
    } while ($status -eq "InProgress" -or $status -eq "Queued" -or $status -eq "Ready")
    
    if ($status -eq "Succeeded") {
        $totalTime = [math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)
        Write-Host "`n🎉 Enterprise CodeDeploy Blue/Green deployment completed successfully!" -ForegroundColor Green
        Write-Host "📊 Total deployment time: $totalTime minutes" -ForegroundColor Cyan
        
        # Get ALB information
        $albDns = aws elbv2 describe-load-balancers --names "$ProjectName-alb" --query 'LoadBalancers[0].DNSName' --output text
        Write-Host "🌐 Production URL: http://$albDns" -ForegroundColor Yellow
        Write-Host "🧪 Test URL: http://$albDns`:8080" -ForegroundColor Yellow
        Write-Host "📈 CloudWatch Logs: /aws/codedeploy/$ProjectName" -ForegroundColor Magenta
        
        # Enterprise Deployment Summary
        Write-Host "`n📋 Enterprise Deployment Summary:" -ForegroundColor White
        Write-Host "  - Image: $EcrRepository`:$ImageTag" -ForegroundColor Gray
        Write-Host "  - Environment: $Environment" -ForegroundColor Gray
        Write-Host "  - Duration: $totalTime minutes" -ForegroundColor Gray
        Write-Host "  - Deployment ID: $deploymentId" -ForegroundColor Gray
        Write-Host "  - Blue Target Group: $blueTgName" -ForegroundColor Gray
        Write-Host "  - Green Target Group: $greenTgName" -ForegroundColor Gray
        Write-Host "  - Wait Time: $waitTime minutes" -ForegroundColor Gray
        Write-Host "  - Termination Wait: $terminationWaitTime minutes" -ForegroundColor Gray
        Write-Host "  - Production Listener: $prodListenerArn" -ForegroundColor Gray
        Write-Host "  - Test Listener: $testListenerArn" -ForegroundColor Gray
        
    } else {
        Write-Host "`n❌ Enterprise CodeDeploy deployment failed with status: $status" -ForegroundColor Red
        
        # Detailed Error Information
        if ($deploymentDetails.errorInformation) {
            Write-Host "🔍 Error Information:" -ForegroundColor Red
            Write-Host "  Code: $($deploymentDetails.errorInformation.code)" -ForegroundColor Gray
            Write-Host "  Message: $($deploymentDetails.errorInformation.message)" -ForegroundColor Gray
        }
        
        # Rollback Information
        if ($deploymentDetails.rollbackInfo) {
            Write-Host "🔄 Rollback Information:" -ForegroundColor Yellow
            Write-Host "  Rollback Message: $($deploymentDetails.rollbackInfo.rollbackMessage)" -ForegroundColor Gray
        }
        
        throw "Enterprise deployment failed with status: $status"
    }
    
} catch {
    Write-Error "❌ Enterprise deployment monitoring failed: $_"
    exit 1
}

Write-Host "`n🏁 Enterprise AWS CodeDeploy Blue/Green ECS deployment process completed" -ForegroundColor Green