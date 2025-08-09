# Blue/Green Deployment Status Monitor
param(
    [string]$ProjectName = "nestjs-hannibal-3",
    [string]$Region = "ap-northeast-1"
)

Write-Host "=== ECS Native Blue/Green Deployment Status ===" -ForegroundColor Green

# Get ALB ARN
$AlbArn = aws elbv2 describe-load-balancers --names "$ProjectName-alb" --region $Region --query 'LoadBalancers[0].LoadBalancerArn' --output text

if ($AlbArn -eq "None") {
    Write-Host "ALB not found: $ProjectName-alb" -ForegroundColor Red
    exit 1
}

# Get Listener ARNs
$ProdListener = aws elbv2 describe-listeners --load-balancer-arn $AlbArn --region $Region --query 'Listeners[?Port==`80`].ListenerArn' --output text
$TestListener = aws elbv2 describe-listeners --load-balancer-arn $AlbArn --region $Region --query 'Listeners[?Port==`8080`].ListenerArn' --output text

Write-Host "`n--- Production Listener (Port 80) ---" -ForegroundColor Yellow
aws elbv2 describe-rules --listener-arn $ProdListener --region $Region --query 'Rules[?Priority==`100`].Actions[0].ForwardConfig.TargetGroups[*].{Arn:TargetGroupArn,Weight:Weight}' --output table

Write-Host "`n--- Test Listener (Port 8080) ---" -ForegroundColor Yellow  
aws elbv2 describe-rules --listener-arn $TestListener --region $Region --query 'Rules[?Priority==`100`].Actions[0].ForwardConfig.TargetGroups[*].{Arn:TargetGroupArn,Weight:Weight}' --output table

# Check ECS Service Status
Write-Host "`n--- ECS Service Deployments ---" -ForegroundColor Yellow
aws ecs describe-services --cluster "$ProjectName-cluster" --services "$ProjectName-api-service" --region $Region --query 'services[0].deployments[*].{Status:status,TaskDefinition:taskDefinition,DesiredCount:desiredCount,RunningCount:runningCount}' --output table

Write-Host "`n--- Weight Sum Verification ---" -ForegroundColor Cyan
$ProdWeightSum = aws elbv2 describe-rules --listener-arn $ProdListener --region $Region --query 'Rules[?Priority==`100`].Actions[0].ForwardConfig.TargetGroups[*].Weight | sum(@)' --output text
$TestWeightSum = aws elbv2 describe-rules --listener-arn $TestListener --region $Region --query 'Rules[?Priority==`100`].Actions[0].ForwardConfig.TargetGroups[*].Weight | sum(@)' --output text

Write-Host "Production (Port 80) Weight Sum: $ProdWeightSum" -ForegroundColor $(if ($ProdWeightSum -eq "100") { "Green" } else { "Red" })
Write-Host "Test (Port 8080) Weight Sum: $TestWeightSum" -ForegroundColor $(if ($TestWeightSum -eq "100") { "Green" } else { "Red" })