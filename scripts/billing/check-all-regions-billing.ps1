# 全リージョンの課金リソース確認スクリプト（完成版 / リージョン配列化修正版）
Write-Host "= 全リージョン課金リソース確認 =" -ForegroundColor Yellow

# 全商用リージョンを動的取得（配列化）
$regions = aws ec2 describe-regions --query "Regions[].RegionName" --output json |
    ConvertFrom-Json

# 集計用ハッシュ
$summary = @{
    EC2 = 0
    RDS = 0
    OpenSearch = 0
    Redshift = 0
    EMR = 0
    SageMaker = 0
    NATGW = 0
    ELB = 0
    EIP = 0
    EBS = 0
}

# 共通実行関数（エラー無視して結果だけ返す）
function Run-AwsQuery($cmd) {
    try {
        Invoke-Expression $cmd 2>$null | ConvertFrom-Json
    } catch {
        return $null
    }
}

foreach ($region in $regions) {
    Write-Host "`n--- $region ---" -ForegroundColor Cyan

    # EC2
    $instances = Run-AwsQuery "aws ec2 describe-instances --region $region --query `"Reservations[*].Instances[?State.Name=='running'].[InstanceId,InstanceType,LaunchTime]`" --output json"
    if ($instances -and $instances.Count -gt 0) {
        $summary.EC2 += $instances.Count
        Write-Host "🔴 実行中EC2: $($instances.Count)個" -ForegroundColor Red
        $instances | ForEach-Object { Write-Host "  - $($_[0]) ($($_[1]))" }
    }

    # RDS
    $rds = Run-AwsQuery "aws rds describe-db-instances --region $region --query `"DBInstances[?DBInstanceStatus=='available'].[DBInstanceIdentifier,DBInstanceClass]`" --output json"
    if ($rds -and $rds.Count -gt 0) {
        $summary.RDS += $rds.Count
        Write-Host "🔴 実行中RDS: $($rds.Count)個" -ForegroundColor Red
        $rds | ForEach-Object { Write-Host "  - $($_[0]) ($($_[1]))" }
    }

    # OpenSearch
    $opensearch = Run-AwsQuery "aws opensearch list-domain-names --region $region --query `"DomainNames[*].DomainName`" --output json"
    if ($opensearch -and $opensearch.Count -gt 0) {
        $summary.OpenSearch += $opensearch.Count
        Write-Host "🔴 OpenSearch: $($opensearch.Count)個" -ForegroundColor Red
        $opensearch | ForEach-Object { Write-Host "  - $_" }
    }

    # Redshift
    $redshift = Run-AwsQuery "aws redshift describe-clusters --region $region --query `"Clusters[?ClusterStatus=='available'].[ClusterIdentifier,NodeType]`" --output json"
    if ($redshift -and $redshift.Count -gt 0) {
        $summary.Redshift += $redshift.Count
        Write-Host "🔴 Redshift: $($redshift.Count)個" -ForegroundColor Red
        $redshift | ForEach-Object { Write-Host "  - $($_[0]) ($($_[1]))" }
    }

    # EMR
    $emr = Run-AwsQuery "aws emr list-clusters --region $region --active --query `"Clusters[*].[Id,Name]`" --output json"
    if ($emr -and $emr.Count -gt 0) {
        $summary.EMR += $emr.Count
        Write-Host "🔴 EMR: $($emr.Count)個" -ForegroundColor Red
        $emr | ForEach-Object { Write-Host "  - $($_[0]) ($($_[1]))" }
    }

    # SageMaker
    $sagemaker = Run-AwsQuery "aws sagemaker list-notebook-instances --region $region --status-equals InService --query `"NotebookInstances[*].[NotebookInstanceName,InstanceType]`" --output json"
    if ($sagemaker -and $sagemaker.Count -gt 0) {
        $summary.SageMaker += $sagemaker.Count
        Write-Host "🔴 SageMaker: $($sagemaker.Count)個" -ForegroundColor Red
        $sagemaker | ForEach-Object { Write-Host "  - $($_[0]) ($($_[1]))" }
    }

    # NAT Gateway
    $nats = Run-AwsQuery "aws ec2 describe-nat-gateways --region $region --query `"NatGateways[?State=='available'].[NatGatewayId]`" --output json"
    if ($nats -and $nats.Count -gt 0) {
        $summary.NATGW += $nats.Count
        Write-Host "🔴 NAT Gateway: $($nats.Count)個" -ForegroundColor Red
    }

    # ELB/ALB
    $elbs = Run-AwsQuery "aws elbv2 describe-load-balancers --region $region --query `"LoadBalancers[?State.Code=='active'].[LoadBalancerName,Type]`" --output json"
    if ($elbs -and $elbs.Count -gt 0) {
        $summary.ELB += $elbs.Count
        Write-Host "🟡 ELB/ALB: $($elbs.Count)個" -ForegroundColor Yellow
    }

    # 未使用EIP
    $eips = Run-AwsQuery "aws ec2 describe-addresses --region $region --query `"Addresses[?!InstanceId].[PublicIp,AllocationId]`" --output json"
    if ($eips -and $eips.Count -gt 0) {
        $summary.EIP += $eips.Count
        Write-Host "⚠️ 未使用Elastic IP: $($eips.Count)個" -ForegroundColor Magenta
    }

    # 未アタッチEBS
    $volumes = Run-AwsQuery "aws ec2 describe-volumes --region $region --query `"Volumes[?State=='available'].[VolumeId,Size]`" --output json"
    if ($volumes -and $volumes.Count -gt 0) {
        $summary.EBS += $volumes.Count
        Write-Host "⚠️ 未アタッチEBS: $($volumes.Count)個" -ForegroundColor Magenta
    }
}

# 最終サマリ表示
Write-Host "`n= 全リージョンサマリ =" -ForegroundColor Green
$summary.GetEnumerator() | Sort-Object Name | ForEach-Object {
    Write-Host ("{0,-12}: {1}" -f $_.Key, $_.Value)
}

Write-Host "`n= 確認完了 =" -ForegroundColor Green
