# AWS Workload Discovery on AWS - Destroy Script
# 使用方法: .\destroy.ps1

Write-Host "=== AWS Workload Discovery on AWS - Destroy Script ===" -ForegroundColor Yellow

# スタック名
$STACK_NAME = "workload-discovery"

Write-Host "1. ECSタスク停止中..." -ForegroundColor Green

# ECSクラスター名を取得
try {
    $clusterArn = aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ClusterArn'].OutputValue" --output text 2>$null
    if ($clusterArn) {
        $clusterName = $clusterArn.Split('/')[-1]
        Write-Host "クラスター名: $clusterName" -ForegroundColor Cyan
        
        # 実行中のタスクを停止
        $tasks = aws ecs list-tasks --cluster $clusterName --query "taskArns" --output text
        if ($tasks -and $tasks -ne "None") {
            Write-Host "タスク停止中..." -ForegroundColor Yellow
            aws ecs stop-task --cluster $clusterName --task $tasks
            Start-Sleep -Seconds 10
        } else {
            Write-Host "実行中のタスクはありません" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "ECSタスク停止をスキップ（スタックが存在しないか、既に削除済み）" -ForegroundColor Yellow
}

Write-Host "2. CloudFormationスタック削除中..." -ForegroundColor Green

# スタック削除
aws cloudformation delete-stack --stack-name $STACK_NAME

Write-Host "3. 削除状況確認中..." -ForegroundColor Green

# 削除完了まで待機
do {
    Start-Sleep -Seconds 30
    $status = aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].StackStatus" --output text 2>$null
    if ($status) {
        Write-Host "削除状況: $status" -ForegroundColor Cyan
    } else {
        Write-Host "削除完了！" -ForegroundColor Green
        break
    }
} while ($status -eq "DELETE_IN_PROGRESS")

Write-Host "=== Workload Discovery削除完了 ===" -ForegroundColor Green
Write-Host "月額コスト削減: 約150-200 USD" -ForegroundColor Yellow