# NestJS Hannibal 3

<div align="center">
  <img src="docs/architecture/cacoo/architecture.svg" alt="AWS Architecture" width="800">
</div>

企業レベルのNestJS + AWS ECS Fargateアプリケーション

## 📋 ドキュメント

- [セットアップガイド](./docs/setup/README.md) - 環境構築・事前準備
- [運用ガイド](./docs/operations/README.md) - IAM管理・監視・分析
- [アーキテクチャ](./docs/architecture/mermaid/README.md) - システム構成図

## 🏗️ AWSアーキテクチャ

<div align="center">
  <img src="docs/architecture/diagrams/latest.png?v=20250806165536" alt="AWS Architecture" width="600">
</div>

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
- **CodeDeploy Blue/Green**: 無停止デプロイメント
- **Docker**: コンテナ化
- **Terraform**: Infrastructure as Code

## 🚀 CodeDeploy Blue/Green ECS デプロイメント

### 主要設定
- **Deployment Config**: `CodeDeployDefault.ECSAllAtOnce`
- **Wait Time**: 1分（高速デプロイ）
- **Termination Wait**: 1分（高速終了）
- **Auto Rollback**: 失敗時自動ロールバック
- **Target Groups**: Blue/Green環境切り替え

### リスナー設定
- **Production Listener**: Port 80 (Blue Target Group)
- **Test Listener**: Port 8080 (Green Target Group)
- **Listener ARNs**: Terraform Outputで取得
  ```bash
  terraform output production_listener_arn
  terraform output test_listener_arn
  ```

### ターゲットグループ
- **Blue Target Group**: `nestjs-hannibal-3-blue-tg`
- **Green Target Group**: `nestjs-hannibal-3-green-tg`
- **Health Check**: `/` パスでHTTP 200レスポンス
- **Target Group Names**: Terraform Outputで取得
  ```bash
  terraform output blue_target_group_name
  terraform output green_target_group_name
  ```

### 手動デプロイ
```powershell
# 基本デプロイ
.\scripts\deployment\deploy-codedeploy.ps1 -ImageTag "v1.2.3"

# 環境指定
.\scripts\deployment\deploy-codedeploy.ps1 -ImageTag "v1.2.3" -Environment "staging"

# Terraformスキップ（インフラ変更なし）
.\scripts\deployment\deploy-codedeploy.ps1 -ImageTag "v1.2.3" -SkipTerraform

# タイムアウト設定
.\scripts\deployment\deploy-codedeploy.ps1 -ImageTag "v1.2.3" -TimeoutMinutes 45
```

### 監視URL
- **Production**: `http://<ALB-DNS>`
- **Test**: `http://<ALB-DNS>:8080`
- **CloudWatch Logs**: `/aws/codedeploy/nestjs-hannibal-3`
- **AWS Console**: `https://console.aws.amazon.com/codesuite/codedeploy/deployments/<DEPLOYMENT-ID>`

### Terraform出力情報
```bash
# CodeDeploy設定情報
terraform output codedeploy_application_name
terraform output codedeploy_deployment_group_name
terraform output codedeploy_wait_time_minutes
terraform output codedeploy_termination_wait_time_minutes

# ネットワーク設定
terraform output production_listener_arn
terraform output test_listener_arn
terraform output blue_target_group_name
terraform output green_target_group_name
```

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
- **CodeDeploy Blue/Green**: 自動ロールバック機能
- **IAM最小権限**: AWS管理ポリシーのみ使用
- **PassRole権限**: ECS Task Execution Roleへの適切な権限委譲