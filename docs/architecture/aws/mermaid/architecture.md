# NestJS Hannibal 3 Architecture

## システム構成図

```mermaid
graph TB
    User[ユーザー] --> DNS[Route53<br/>hamilcar-hannibal.click]
    DNS --> CF[CloudFront<br/>Distribution]
    
    CF --> |"Static Files<br/>(/, /assets/*)"| S3[S3 Bucket<br/>Frontend Assets]
    CF --> |"API Requests<br/>(/api/*)"| ALB[Application<br/>Load Balancer]
    
    subgraph VPC["VPC (ap-northeast-1)"]
        subgraph PublicSubnet["Public Subnets"]
            ALB
        end
        
        subgraph ECSCluster["ECS Fargate Cluster"]
            ALB --> ECS[ECS Service<br/>NestJS API]
            ECR[ECR<br/>Container Registry] --> |"Pull Image"| ECS
        end
    end
    
    ECS --> RDS[RDS PostgreSQL<br/>Database]
    
    subgraph Security["Security & Monitoring"]
        IAM[IAM Role<br/>ECS Task Execution] -.-> ECS
        ECS -.-> CW[CloudWatch<br/>Logs]
    end
    
    style User fill:#e1f5fe
    style DNS fill:#fff3e0
    style CF fill:#fff3e0
    style S3 fill:#e8f5e8
    style ALB fill:#fff3e0
    style ECS fill:#e3f2fd
    style ECR fill:#e3f2fd
    style RDS fill:#fce4ec
    style IAM fill:#fff8e1
    style CW fill:#f3e5f5
```

## コンポーネント詳細

### Frontend & CDN
- **Route53**: DNS管理とドメイン解決
- **CloudFront**: CDN、静的ファイル配信とAPIプロキシ
- **S3**: React アプリケーションの静的ファイル保存

### Application Layer
- **ALB**: HTTPSトラフィックの負荷分散
- **ECS Fargate**: NestJS APIのコンテナ実行環境
- **ECR**: Dockerイメージの保存とバージョン管理

### Database Layer
- **RDS PostgreSQL**: アプリケーションデータの永続化

### Security & Monitoring
- **IAM Role**: ECSタスクの実行権限管理
- **CloudWatch**: アプリケーションログとメトリクス監視

## トラフィックフロー

1. **静的ファイル**: User → Route53 → CloudFront → S3
2. **API リクエスト**: User → Route53 → CloudFront → ALB → ECS → RDS
3. **デプロイ**: ECR → ECS (新しいコンテナイメージのプル)
4. **監視**: ECS → CloudWatch (ログとメトリクス送信)