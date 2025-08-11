param(
    [Parameter(Mandatory=$true)]
    [string]$ImageTag,
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipTerraform,
    
    [Parameter(Mandatory=$false)]
    [int]$TimeoutMinutes = 30
)

$ErrorActionPreference = "Stop"

# プロジェクト設定
$PROJECT_NAME = "nestjs-hannibal-3"
$AWS_REGION = "ap-northeast-1"
$AWS_ACCOUNT_ID = "258632448142"

Write-Host "🚀 Starting CodeDeploy Blue/Green Deployment" -ForegroundColor Green
Write-Host "📋 Configuration:" -ForegroundColor Cyan
Write-Host "  - Project: $PROJECT_NAME" -ForegroundColor White
Write-Host "  - Environment: $Environment" -ForegroundColor White
Write-Host "  - Image Tag: $ImageTag" -ForegroundColor White
Write-Host "  - Skip Terraform: $SkipTerraform" -ForegroundColor White
Write-Host "  - Timeout: $TimeoutMinutes minutes" -ForegroundColor White

try {
    # Terraform実行（スキップしない場合）
    if (-not $SkipTerraform) {
        Write-Host "🏗️ Applying Terraform changes..." -ForegroundColor Yellow
        Set-Location "terraform\backend"
        
        terraform init -input=false
        if ($LASTEXITCODE -ne 0) { throw "Terraform init failed" }
        
        terraform plan -var="environment=$Environment" -out=tfplan
        if ($LASTEXITCODE -ne 0) { throw "Terraform plan failed" }
        
        terraform apply -auto-approve tfplan
        if ($LASTEXITCODE -ne 0) { throw "Terraform apply failed" }
        
        terraform output -json > "..\..\tf_outputs_backend.json"
        Set-Location "..\..\"
        
        Write-Host "✅ Terraform applied successfully" -ForegroundColor Green
    }

    # ECRイメージ確認
    $ECR_URI = "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT_NAME"
    $NEW_IMAGE = "$ECR_URI`:$ImageTag"
    
    Write-Host "🐳 Verifying Docker image: $NEW_IMAGE" -ForegroundColor Yellow
    aws ecr describe-images --repository-name $PROJECT_NAME --image-ids imageTag=$ImageTag --region $AWS_REGION | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker image $NEW_IMAGE not found in ECR"
    }
    
    # 現在のタスク定義取得
    Write-Host "📋 Getting current task definition..." -ForegroundColor Yellow
    $TASK_DEF_JSON = aws ecs describe-task-definition --task-definition "$PROJECT_NAME-api-task" --query 'taskDefinition' --region $AWS_REGION
    if ($LASTEXITCODE -ne 0) { throw "Failed to get task definition" }
    
    # 新しいタスク定義作成
    Write-Host "🔄 Creating new task definition with image: $NEW_IMAGE" -ForegroundColor Yellow
    $TASK_DEF = $TASK_DEF_JSON | ConvertFrom-Json
    $TASK_DEF.containerDefinitions[0].image = $NEW_IMAGE
    
    # 不要なプロパティ削除
    $TASK_DEF.PSObject.Properties.Remove('taskDefinitionArn')
    $TASK_DEF.PSObject.Properties.Remove('revision')
    $TASK_DEF.PSObject.Properties.Remove('status')
    $TASK_DEF.PSObject.Properties.Remove('requiresAttributes')
    $TASK_DEF.PSObject.Properties.Remove('placementConstraints')
    $TASK_DEF.PSObject.Properties.Remove('compatibilities')
    $TASK_DEF.PSObject.Properties.Remove('registeredAt')
    $TASK_DEF.PSObject.Properties.Remove('registeredBy')
    
    # タスク定義登録
    $NEW_TASK_DEF_JSON = $TASK_DEF | ConvertTo-Json -Depth 10 -Compress
    $NEW_TASK_DEF_ARN = ($NEW_TASK_DEF_JSON | aws ecs register-task-definition --cli-input-json file://- --query 'taskDefinition.taskDefinitionArn' --output text --region $AWS_REGION)
    if ($LASTEXITCODE -ne 0) { throw "Failed to register new task definition" }
    
    Write-Host "✅ New task definition registered: $NEW_TASK_DEF_ARN" -ForegroundColor Green
    
    # appspec.yaml作成
    Write-Host "📝 Creating appspec.yaml..." -ForegroundColor Yellow
    $APPSPEC_CONTENT = @"
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: "$NEW_TASK_DEF_ARN"
        LoadBalancerInfo:
          ContainerName: "$PROJECT_NAME-container"
          ContainerPort: 3000
"@
    
    # BOMなしUTF8で出力（CodeDeploy要件）
    [System.IO.File]::WriteAllText("appspec.yaml", $APPSPEC_CONTENT, [System.Text.UTF8Encoding]::new(`$false))
    
    # S3にアップロード
    $S3_BUCKET = "$PROJECT_NAME-codedeploy-artifacts"
    $S3_KEY = "appspec-$(Get-Date -Format 'yyyyMMdd-HHmmss').yaml"
    
    Write-Host "📤 Uploading appspec to S3: s3://$S3_BUCKET/$S3_KEY" -ForegroundColor Yellow
    aws s3 cp appspec.yaml "s3://$S3_BUCKET/$S3_KEY" --region $AWS_REGION
    if ($LASTEXITCODE -ne 0) { throw "Failed to upload appspec to S3" }
    
    # CodeDeployデプロイ開始
    Write-Host "🚀 Starting CodeDeploy deployment..." -ForegroundColor Yellow
    $DEPLOYMENT_ID = (aws deploy create-deployment --application-name "$PROJECT_NAME-app" --deployment-group-name "$PROJECT_NAME-dg" --s3-location "bucket=$S3_BUCKET,key=$S3_KEY,bundleType=YAML" --query 'deploymentId' --output text --region $AWS_REGION)
    if ($LASTEXITCODE -ne 0) { throw "Failed to create CodeDeploy deployment" }
    
    Write-Host "✅ CodeDeploy deployment started: $DEPLOYMENT_ID" -ForegroundColor Green
    Write-Host "📊 Monitor deployment: https://console.aws.amazon.com/codesuite/codedeploy/deployments/$DEPLOYMENT_ID" -ForegroundColor Cyan
    
    # デプロイ完了待機
    Write-Host "⏳ Waiting for Blue/Green deployment to complete (timeout: $TimeoutMinutes minutes)..." -ForegroundColor Yellow
    
    $timeout = (Get-Date).AddMinutes($TimeoutMinutes)
    do {
        Start-Sleep -Seconds 30
        $status = (aws deploy get-deployment --deployment-id $DEPLOYMENT_ID --query 'deploymentInfo.status' --output text --region $AWS_REGION)
        Write-Host "  Status: $status" -ForegroundColor White
        
        if ($status -eq "Succeeded") {
            Write-Host "✅ CodeDeploy Blue/Green deployment completed successfully!" -ForegroundColor Green
            break
        }
        elseif ($status -eq "Failed" -or $status -eq "Stopped") {
            $errorInfo = (aws deploy get-deployment --deployment-id $DEPLOYMENT_ID --query 'deploymentInfo.errorInformation' --region $AWS_REGION)
            Write-Host "❌ Deployment failed: $errorInfo" -ForegroundColor Red
            throw "CodeDeploy deployment failed"
        }
    } while ((Get-Date) -lt $timeout)
    
    if ((Get-Date) -ge $timeout) {
        throw "Deployment timed out after $TimeoutMinutes minutes"
    }
    
    # 結果表示
    if (Test-Path "tf_outputs_backend.json") {
        $outputs = Get-Content "tf_outputs_backend.json" | ConvertFrom-Json
        $ALB_DNS = $outputs.alb_dns_name.value
        
        Write-Host "🌐 Deployment URLs:" -ForegroundColor Cyan
        Write-Host "  Production: http://$ALB_DNS" -ForegroundColor Green
        Write-Host "  Test: http://$ALB_DNS`:8080" -ForegroundColor Yellow
    }
    
    Write-Host "🎉 CodeDeploy Blue/Green deployment completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    # クリーンアップ
    if (Test-Path "appspec.yaml") {
        Remove-Item "appspec.yaml" -Force
    }
}