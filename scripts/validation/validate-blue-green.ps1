# Blue/Green初期状態検証スクリプト
param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectName = "nestjs-hannibal-3",
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "ap-northeast-1"
)

Write-Host "🔍 Blue/Green初期状態検証" -ForegroundColor Green
Write-Host ""

# 1. ECSサービスのOriginal Target Group確認
Write-Host "1. ECSサービスのOriginal Target Group確認" -ForegroundColor Blue
$service = aws ecs describe-services --cluster "$ProjectName-cluster" --services "$ProjectName-api-service" --region $Region | ConvertFrom-Json
$primaryTaskSet = $service.services[0].taskSets | Where-Object { $_.status -eq "PRIMARY" }

if ($primaryTaskSet) {
    $originalTG = $primaryTaskSet.loadBalancers[0].targetGroupArn
    $tgName = aws elbv2 describe-target-groups --target-group-arns $originalTG --query 'TargetGroups[0].TargetGroupName' --output text --region $Region
    
    if ($tgName -like "*blue*") {
        Write-Host "✅ Original Target Group: $tgName (正常)" -ForegroundColor Green
    } else {
        Write-Host "❌ Original Target Group: $tgName (異常 - Blueであるべき)" -ForegroundColor Red
    }
} else {
    Write-Host "❌ PRIMARY TaskSetが見つかりません" -ForegroundColor Red
}

# 2. CodeDeploy DGのTarget Group順序確認
Write-Host "`n2. CodeDeploy DGのTarget Group順序確認" -ForegroundColor Blue
$dg = aws deploy get-deployment-group --application-name "$ProjectName-app" --deployment-group-name "$ProjectName-dg" --region $Region | ConvertFrom-Json
$targetGroups = $dg.deploymentGroupInfo.loadBalancerInfo.targetGroupPairInfoList[0].targetGroups

Write-Host "Target Group順序:" -ForegroundColor Yellow
for ($i = 0; $i -lt $targetGroups.Count; $i++) {
    $tgName = $targetGroups[$i].name
    $position = if ($i -eq 0) { "Original" } else { "Replacement" }
    $color = if ($i -eq 0 -and $tgName -like "*blue*") { "Green" } else { "White" }
    Write-Host "  $($i + 1). $tgName ($position)" -ForegroundColor $color
}

# 3. 推奨修正アクション
Write-Host "`n3. 推奨修正アクション" -ForegroundColor Blue
if ($tgName -notlike "*blue*") {
    Write-Host "❌ ECSサービスを再作成してください:" -ForegroundColor Red
    Write-Host "  terraform taint aws_ecs_service.api" -ForegroundColor Yellow
    Write-Host "  terraform apply" -ForegroundColor Yellow
} else {
    Write-Host "✅ 設定は正常です" -ForegroundColor Green
}

Write-Host "`n検証完了" -ForegroundColor Green