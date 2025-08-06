# NestJS Hannibal 3

企業レベルのNestJS + AWS ECS Fargateアプリケーション

## 📋 ドキュメント

- [セットアップガイド](./docs/setup/README.md) - 環境構築・事前準備
- [運用ガイド](./docs/operations/README.md) - IAM管理・監視・分析
- [アーキテクチャ](./docs/architecture/mermaid/README.md) - システム構成図

## 🏗️ AWSアーキテクチャ

```mermaid
graph TB
    %% User Layer
    User[👤 User/Browser]
    
    %% CDN & DNS Layer
    Route53[🌐 Route 53<br/>hamilcar-hannibal.click]
    CloudFront[☁️ CloudFront Distribution<br/>Global CDN]
    
    %% Frontend Layer
    S3[📦 S3 Bucket<br/>nestjs-hannibal-3-frontend<br/>Static Files]
    
    %% Load Balancer Layer
    ALB[⚖️ Application Load Balancer<br/>Port 80 Production<br/>Port 8080 Test]
    
    %% Container Layer
    ECS[🐳 ECS Fargate Service<br/>Blue/Green Deployment<br/>NestJS API]
    ECR[📋 ECR Repository<br/>nestjs-hannibal-3<br/>Container Images]
    
    %% Database Layer
    RDS[🗄️ RDS PostgreSQL<br/>nestjs-hannibal-3-postgres<br/>Encrypted Storage]
    
    %% Monitoring Layer
    CloudWatch[📊 CloudWatch Logs<br/>ECS Task Logs]
    CloudTrail[🔍 CloudTrail<br/>API Call Audit]
    Athena[📈 Athena<br/>Permission Analysis]
    
    %% Security Layer
    subgraph "🔒 Security Groups"
        ALB_SG[ALB SG<br/>Port 80 8080 from Internet]
        ECS_SG[ECS SG<br/>Port 3000 from ALB only]
        RDS_SG[RDS SG<br/>Port 5432 from ECS only]
    end
    
    %% IAM Layer
    subgraph "🔐 IAM Roles & Policies"
        ECS_Role[ECS Task Execution Role<br/>+ Permission Boundary]
        Service_Role[ECS Service Role<br/>Blue/Green Permissions]
        CICD_Role[CICD Role<br/>Minimal Permissions]
    end
    
    %% Network Layer
    subgraph "🌐 VPC Default"
        subgraph "Public Subnets Multi-AZ"
            ALB
            ECS
            RDS
        end
    end
    
    %% CI/CD Layer
    GitHub[🔄 GitHub Actions<br/>CI/CD Pipeline]
    
    %% User Flow
    User --> Route53
    Route53 --> CloudFront
    CloudFront --> |Static Files| S3
    CloudFront --> |/api/*| ALB
    ALB --> ECS
    ECS --> RDS
    ECS --> CloudWatch
    
    %% CI/CD Flow
    GitHub --> ECR
    GitHub --> S3
    GitHub --> ECS
    
    %% Security Associations
    ALB -.-> ALB_SG
    ECS -.-> ECS_SG
    RDS -.-> RDS_SG
    ECS -.-> ECS_Role
    ECS -.-> Service_Role
    GitHub -.-> CICD_Role
    
    %% Monitoring Flow
    ECS --> CloudTrail
    CloudTrail --> Athena
    
    %% Styling
    classDef userLayer fill:#e1f5fe
    classDef cdnLayer fill:#f3e5f5
    classDef frontendLayer fill:#e8f5e8
    classDef backendLayer fill:#fff3e0
    classDef dataLayer fill:#fce4ec
    classDef securityLayer fill:#ffebee
    classDef cicdLayer fill:#f1f8e9
    
    class User userLayer
    class Route53,CloudFront cdnLayer
    class S3 frontendLayer
    class ALB,ECS,ECR backendLayer
    class RDS,CloudWatch,CloudTrail,Athena dataLayer
    class ALB_SG,ECS_SG,RDS_SG,ECS_Role,Service_Role,CICD_Role securityLayer
    class GitHub cicdLayer
```

## 🔧 技術スタック

### フロントエンド
- **React + TypeScript**: モダンなUI開発
- **GraphQL**: 効率的なデータ取得
- **Vite**: 高速ビルドツール

### バックエンド
- **NestJS**: エンタープライズ級Node.jsフレームワーク
- **GraphQL + REST**: ハイブリッドAPI設計
- **PostgreSQL**: リレーショナルデータベース

### インフラストラクチャ
- **AWS ECS Fargate**: サーバーレスコンテナ
- **CloudFront + S3**: グローバルCDN
- **Application Load Balancer**: 高可用性ロードバランシング

### CI/CD
- **GitHub Actions**: 自動化パイプライン
- **Docker**: コンテナ化
- **Terraform**: Infrastructure as Code

## 🔐 AWS Professional設計

### 設計原則
- **基盤とアプリケーションの分離**: IAMユーザー・基本ロールは永続化
- **最小権限原則**: CloudTrail分析による権限最適化（160個→76個、52%削減）
- **Infrastructure as Code**: Terraformによる完全なインフラ管理
- **無停止デプロイメント**: ECS Native Blue/Green Deployment

### セキュリティ
- **Permission Boundary**: 最大権限の制限
- **CloudTrail監査**: 全API呼び出しの記録・分析
- **AssumeRole**: 環境別権限分離