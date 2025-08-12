# 全リージョンの課金リソース確認スクリプト

$regions = @(
    "us-east-1", "us-east-2", "us-west-1", "us-west-2",
    "ap-northeast-1", "ap-northeast-2", "ap-northeast-3", "ap-southeast-1", "ap-southeast-2",
    "eu-west-1", "eu-west-2", "eu-central-1"
)

Write-Host "=== 全リージョン課金リソース確認 ===" -ForegroundColor Yellow

foreach ($region in $regions) {
    Write-Host "`n--- $region ---" -ForegroundColor Cyan
    
    # EC2インスタンス
    $instances = aws ec2 describe-instances --region $region --query "Reservations[*].Instances[?State.Name=='running'].[InstanceId,InstanceType,LaunchTime]" --output json 2>$null | ConvertFrom-Json
    if ($instances -and $instances.Count -gt 0) {
        Write-Host "🔴 実行中EC2: $($instances.Count)個" -ForegroundColor Red
        $instances | ForEach-Object { Write-Host "  - $($_[0]) ($($_[1]))" }
    }
    
    # RDSインスタンス
    $rds = aws rds describe-db-instances --region $region --query "DBInstances[?DBInstanceStatus=='available'].[DBInstanceIdentifier,DBInstanceClass]" --output json 2>$null | ConvertFrom-Json
    if ($rds -and $rds.Count -gt 0) {
        Write-Host "🔴 実行中RDS: $($rds.Count)個" -ForegroundColor Red
        $rds | ForEach-Object { Write-Host "  - $($_[0]) ($($_[1]))" }
    }
    
    # OpenSearch/Elasticsearch
    $opensearch = aws opensearch list-domain-names --region $region --query "DomainNames[*].DomainName" --output json 2>$null | ConvertFrom-Json
    if ($opensearch -and $opensearch.Count -gt 0) {
        Write-Host "🔴 OpenSearch: $($opensearch.Count)個" -ForegroundColor Red
        $opensearch | ForEach-Object { Write-Host "  - $_" }
    }
    
    # Redshift
    $redshift = aws redshift describe-clusters --region $region --query "Clusters[?ClusterStatus=='available'].[ClusterIdentifier,NodeType]" --output json 2>$null | ConvertFrom-Json
    if ($redshift -and $redshift.Count -gt 0) {
        Write-Host "🔴 Redshift: $($redshift.Count)個" -ForegroundColor Red
        $redshift | ForEach-Object { Write-Host "  - $($_[0]) ($($_[1]))" }
    }
    
    # EMR
    $emr = aws emr list-clusters --region $region --active --query "Clusters[*].[Id,Name]" --output json 2>$null | ConvertFrom-Json
    if ($emr -and $emr.Count -gt 0) {
        Write-Host "🔴 EMR: $($emr.Count)個" -ForegroundColor Red
        $emr | ForEach-Object { Write-Host "  - $($_[0]) ($($_[1]))" }
    }
    
    # SageMaker
    $sagemaker = aws sagemaker list-notebook-instances --region $region --status-equals InService --query "NotebookInstances[*].[NotebookInstanceName,InstanceType]" --output json 2>$null | ConvertFrom-Json
    if ($sagemaker -and $sagemaker.Count -gt 0) {
        Write-Host "🔴 SageMaker: $($sagemaker.Count)個" -ForegroundColor Red
        $sagemaker | ForEach-Object { Write-Host "  - $($_[0]) ($($_[1]))" }
    }
    
    # NAT Gateway
    $nats = aws ec2 describe-nat-gateways --region $region --query "NatGateways[?State=='available'].[NatGatewayId]" --output json 2>$null | ConvertFrom-Json
    if ($nats -and $nats.Count -gt 0) {
        Write-Host "🔴 NAT Gateway: $($nats.Count)個" -ForegroundColor Red
    }
    
    # ELB/ALB
    $elbs = aws elbv2 describe-load-balancers --region $region --query "LoadBalancers[?State.Code=='active'].[LoadBalancerName,Type]" --output json 2>$null | ConvertFrom-Json
    if ($elbs -and $elbs.Count -gt 0) {
        Write-Host "🟡 ELB/ALB: $($elbs.Count)個" -ForegroundColor Yellow
    }
    
    # 未使用Elastic IP
    $eips = aws ec2 describe-addresses --region $region --query "Addresses[?!InstanceId].[PublicIp,AllocationId]" --output json 2>$null | ConvertFrom-Json
    if ($eips -and $eips.Count -gt 0) {
        Write-Host "⚠️ 未使用Elastic IP: $($eips.Count)個" -ForegroundColor Magenta
    }
    
    # 未アタッチEBS
    $volumes = aws ec2 describe-volumes --region $region --query "Volumes[?State=='available'].[VolumeId,Size]" --output json 2>$null | ConvertFrom-Json
    if ($volumes -and $volumes.Count -gt 0) {
        Write-Host "⚠️ 未アタッチEBS: $($volumes.Count)個" -ForegroundColor Magenta
    }
}

Write-Host "`n=== 確認完了 ===" -ForegroundColor Green