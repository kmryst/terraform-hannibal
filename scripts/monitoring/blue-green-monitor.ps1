# Blue/Green Deployment Monitor Script
# 一時的な監視用スクリプト

$iteration = 1
while ($true) {
    Write-Host "`n==================== UPDATE #$iteration - $(Get-Date) ====================" -ForegroundColor Green
    
    try {
        # ECS Deployments
        Write-Host "`n--- ECS Deployments ---" -ForegroundColor Cyan
        aws ecs describe-services --cluster nestjs-hannibal-3-cluster --services nestjs-hannibal-3-api-service --query 'services[0].deployments[*].{Status:status,TaskDef:taskDefinition,Running:runningCount,Desired:desiredCount,UpdatedAt:updatedAt}' --output table
        
        # Blue Target Group Health
        Write-Host "`n--- Blue TG Health ---" -ForegroundColor Blue
        $blueTgArn = aws elbv2 describe-target-groups --names nestjs-hannibal-3-blue-tg --query 'TargetGroups[0].TargetGroupArn' --output text
        if ($blueTgArn -and $blueTgArn -ne "None") {
            aws elbv2 describe-target-health --target-group-arn $blueTgArn --query 'TargetHealthDescriptions[*].{Target:Target.Id,Port:Target.Port,Health:TargetHealth.State,Reason:TargetHealth.Reason}' --output table
        } else {
            Write-Host "Blue TG not found or no targets" -ForegroundColor Yellow
        }
        
        # Green Target Group Health
        Write-Host "`n--- Green TG Health ---" -ForegroundColor Green
        $greenTgArn = aws elbv2 describe-target-groups --names nestjs-hannibal-3-green-tg --query 'TargetGroups[0].TargetGroupArn' --output text
        if ($greenTgArn -and $greenTgArn -ne "None") {
            aws elbv2 describe-target-health --target-group-arn $greenTgArn --query 'TargetHealthDescriptions[*].{Target:Target.Id,Port:Target.Port,Health:TargetHealth.State,Reason:TargetHealth.Reason}' --output table
        } else {
            Write-Host "Green TG not found or no targets" -ForegroundColor Yellow
        }
        
        # ALB Listener Rules (Weight-based routing)
        Write-Host "`n--- ALB Listener Rules (Production Port 80) ---" -ForegroundColor Yellow
        $albArn = aws elbv2 describe-load-balancers --names nestjs-hannibal-3-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text
        if ($albArn -and $albArn -ne "None") {
            $listenerArn = aws elbv2 describe-listeners --load-balancer-arn $albArn --query 'Listeners[?Port==`80`].ListenerArn' --output text
            if ($listenerArn -and $listenerArn -ne "None") {
                aws elbv2 describe-rules --listener-arn $listenerArn --query 'Rules[?Priority==`100`].Actions[0].ForwardConfig.TargetGroups[*].{TargetGroup:TargetGroupArn,Weight:Weight}' --output table
            }
        }
        
        # Test Listener (Port 8080)
        Write-Host "`n--- Test Listener (Port 8080) ---" -ForegroundColor Cyan
        if ($albArn -and $albArn -ne "None") {
            $testListenerArn = aws elbv2 describe-listeners --load-balancer-arn $albArn --query 'Listeners[?Port==`8080`].ListenerArn' --output text
            if ($testListenerArn -and $testListenerArn -ne "None") {
                aws elbv2 describe-rules --listener-arn $testListenerArn --query 'Rules[?Priority==`100`].Actions[0].ForwardConfig.TargetGroups[*].{TargetGroup:TargetGroupArn,Weight:Weight}' --output table
            }
        }
        
        # ECS Tasks (追加情報)
        Write-Host "`n--- Running Tasks ---" -ForegroundColor Magenta
        aws ecs list-tasks --cluster nestjs-hannibal-3-cluster --service-name nestjs-hannibal-3-api-service --query 'taskArns[*]' --output table
        
    } catch {
        Write-Host "Error occurred: $_" -ForegroundColor Red
    }
    
    Write-Host "`n--- Next update in 15 seconds (Ctrl+C to stop) ---" -ForegroundColor Gray
    $iteration++
    Start-Sleep 15
}