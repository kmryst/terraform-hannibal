# IAM権限構成

## 🔐 IAM アーキテクチャ

```mermaid
graph TB
    %% Users
    subgraph "👤 IAM Users"
        Hannibal[hannibal<br/>Developer]
        CICD[hannibal-cicd<br/>CI/CD Automation]
    end
    
    %% Roles
    subgraph "🎭 IAM Roles"
        Dev_Role[HannibalDeveloperRole-Dev<br/>Development Access]
        CICD_Role[HannibalCICDRole-Dev<br/>CI/CD Access]
        ECS_Exec_Role[ECS Task Execution Role<br/>Container Management]
        ECS_Service_Role[ECS Service Role<br/>Blue/Green Operations]
    end
    
    %% Policies
    subgraph "📋 IAM Policies"
        Dev_Policy[HannibalDeveloperPolicy-Dev<br/>Full Development Access]
        CICD_Policy[HannibalCICDPolicy-Dev-Minimal<br/>76 Permissions Optimized]
        AWS_ECS_Policy[AmazonECSTaskExecutionRolePolicy<br/>AWS Managed]
        BG_Policy[Blue/Green Policy<br/>ALB + ECS Operations]
    end
    
    %% Permission Boundaries
    subgraph "🛡️ Permission Boundaries"
        CICD_Boundary[HannibalCICDBoundary<br/>Maximum Allowed Permissions]
        ECS_Boundary[HannibalECSBoundary<br/>Container Restrictions]
    end
    
    %% Assume Role Relationships
    Hannibal --> |AssumeRole| Dev_Role
    CICD --> |AssumeRole| CICD_Role
    
    %% Policy Attachments
    Dev_Role --> Dev_Policy
    CICD_Role --> CICD_Policy
    ECS_Exec_Role --> AWS_ECS_Policy
    ECS_Service_Role --> BG_Policy
    
    %% Permission Boundaries
    CICD_Role -.-> |Bounded by| CICD_Boundary
    ECS_Exec_Role -.-> |Bounded by| ECS_Boundary
    
    %% AWS Services
    subgraph "⚙️ AWS Services"
        ECS_Service[ECS Service]
        ECS_Tasks[ECS Tasks]
    end
    
    ECS_Service --> |Uses| ECS_Service_Role
    ECS_Tasks --> |Uses| ECS_Exec_Role
    
    %% Styling
    classDef user fill:#e1f5fe
    classDef role fill:#f3e5f5
    classDef policy fill:#e8f5e8
    classDef boundary fill:#ffebee
    classDef service fill:#fff3e0
    
    class Hannibal,CICD user
    class Dev_Role,CICD_Role,ECS_Exec_Role,ECS_Service_Role role
    class Dev_Policy,CICD_Policy,AWS_ECS_Policy,BG_Policy policy
    class CICD_Boundary,ECS_Boundary boundary
    class ECS_Service,ECS_Tasks service
```

## 🏗️ 設計原則

### 基盤とアプリケーションの分離
- **基盤IAMリソース**: 手動管理・永続保持
- **アプリケーションIAMリソース**: Terraform管理・一時的

### 最小権限の原則
- **CloudTrail分析**: 実際の使用権限（76個）を特定
- **Permission Boundary**: 最大権限の制限
- **段階的権限縮小**: 160個 → 76個（52%削減）

### 環境分離
- **開発環境**: HannibalDeveloperRole-Dev
- **CI/CD環境**: HannibalCICDRole-Dev
- **本番環境**: 将来的に別アカウント分離

## 📊 権限最適化結果

### CI/CD権限分析 2025年7月27日
- **分析前**: 160個の権限
- **実際使用**: 76個の権限
- **削減率**: 52%の権限削減達成

### 企業レベル監査
- **CloudTrail**: 全API呼び出しを記録
- **Athena分析**: 権限使用パターンの可視化
- **継続的最適化**: 定期的な権限見直し

## 🔒 セキュリティ機能

### Permission Boundary
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": [
        "iam:CreateUser",
        "iam:DeleteUser",
        "organizations:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### AssumeRole設定
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::258632448142:user/hannibal-cicd"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "unique-external-id"
        }
      }
    }
  ]
}
```