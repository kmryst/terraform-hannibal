# Blue/Green Deployment

## 🔄 ECS Native Blue/Green Deployment

```mermaid
graph LR
    %% Current State
    subgraph "🔵 Blue Environment (Current)"
        Blue_TG[Blue Target Group<br/>Port 3000]
        Blue_Task[ECS Task v1.0<br/>Running]
    end
    
    %% New Deployment
    subgraph "🟢 Green Environment (New)"
        Green_TG[Green Target Group<br/>Port 3000]
        Green_Task[ECS Task v2.0<br/>Deploying]
    end
    
    %% Load Balancer
    ALB_Prod[ALB Production<br/>Port 80]
    ALB_Test[ALB Test<br/>Port 8080]
    
    %% Traffic Flow
    Users[👥 Users]
    Tester[🧪 Tester]
    
    %% Current Traffic
    Users --> ALB_Prod
    ALB_Prod --> Blue_TG
    Blue_TG --> Blue_Task
    
    %% Test Traffic
    Tester --> ALB_Test
    ALB_Test --> Green_TG
    Green_TG --> Green_Task
    
    %% Deployment Process
    Deploy[🚀 Deploy Trigger] --> Green_Task
    Green_Task --> |Health Check OK| Switch[⚡ Traffic Switch]
    Switch --> |Automatic| ALB_Prod
    ALB_Prod -.-> |Switch to| Green_TG
    Blue_Task -.-> |Terminate| Cleanup[🗑️ Cleanup]
    
    %% Styling
    classDef blue fill:#e3f2fd
    classDef green fill:#e8f5e8
    classDef alb fill:#fff3e0
    classDef user fill:#f3e5f5
    
    class Blue_TG,Blue_Task blue
    class Green_TG,Green_Task green
    class ALB_Prod,ALB_Test alb
    class Users,Tester user
```

## 🎯 デプロイメント手順

### 1. 準備フェーズ
- 新しいコンテナイメージをECRにプッシュ
- Green環境用のタスク定義を作成

### 2. デプロイフェーズ
- Green環境でECSタスクを起動
- ヘルスチェックで正常性を確認
- テストリスナー（Port 8080）で事前検証

### 3. 切り替えフェーズ
- プロダクションリスナー（Port 80）をGreenに切り替え
- Blue環境のタスクを自動終了
- 完全な無停止デプロイメント完了

## ⚡ 主要メリット

### CodeDeploy不要
- **ECS単体**: CodeDeployアプリケーション・デプロイメントグループが不要
- **シンプル**: 複雑な設定や依存関係を排除
- **高速**: デプロイ時間の短縮

### 無停止デプロイ
- **ゼロダウンタイム**: ユーザーへの影響なし
- **自動ロールバック**: ヘルスチェック失敗時の自動復旧
- **Dark Canary**: 本番トラフィック前のテスト可能

### 企業レベル品質
- **Netflix方式**: 大規模サービスで実証済み
- **監査対応**: 全デプロイ履歴をCloudTrailで追跡
- **Permission Boundary**: 最小権限でのセキュア運用