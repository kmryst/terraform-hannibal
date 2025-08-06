# AWS Workload Discovery on AWS Rules

## 概要
AWS Workload Discovery on AWSは、AWSクラウドのワークロードをアーキテクチャ図として自動的に可視化するソリューションです。

## 重要な前提条件

### 1. デプロイ方法
- **標準のAWS CLIコマンドは存在しない**
- **CloudFormationテンプレートを使用した正式デプロイが必須**
- 専用のCLIツールではなく、CloudFormationベースのソリューション

### 2. 必要な前提条件
- **AWS Config**が設定されていることが必須
- **AWSServiceRoleForAmazonOpenSearchService**ロールの確認
- **専用AWSアカウント**での運用を推奨

## デプロイ手順

### 1. CloudFormationテンプレート
```
workload-discovery-on-aws.template
```

### 2. 前提条件確認コマンド
```bash
# AWS Config設定確認
aws configservice get-status

# OpenSearchServiceロール確認
aws iam get-role --role-name AWSServiceRoleForAmazonOpenSearchService
```

### 3. デプロイパラメータ（重要）
| パラメータ | デフォルト | 説明 |
|-----------|-----------|------|
| AdminUserEmailAddress | 必須入力 | 初期ユーザーのメールアドレス |
| AlreadyHaveConfigSetup | No | AWS Config設定済みかどうか |
| CreateOpenSearchServiceRole | Yes | OpenSearchServiceロール作成要否 |
| NeptuneInstanceClass | db.r5.large | Neptuneインスタンスタイプ |
| OpensearchInstanceType | m6g.large.search | OpenSearchインスタンスタイプ |

## コスト情報

### 単一インスタンス構成（デフォルト）
- **時間あたり**: 約0.58 USD
- **月額**: 約425.19 USD
- **主要コスト**: Amazon Neptune (254.04 USD/月)

### 複数インスタンス構成（高可用性）
- **時間あたり**: 約1.062 USD  
- **月額**: 約772.67 USD

## アーキテクチャコンポーネント

### 主要サービス
1. **Amazon CloudFront** - ウェブUI配信
2. **Amazon S3** - ウェブUIホスティング
3. **Amazon Cognito** - ユーザー認証
4. **AWS AppSync** - GraphQL API
5. **Amazon Neptune** - グラフデータベース
6. **Amazon OpenSearch Service** - 検索・分析
7. **Amazon ECS + AWS Fargate** - 検出コンポーネント
8. **AWS Config** - リソース設定収集

### データフロー
1. **15分間隔**でAWS Fargateタスクが実行
2. **AWS Config + AWS SDK**でリソース情報収集
3. **Amazon Neptune**にリソース関係性を保存
4. **Amazon OpenSearch Service**で検索可能に

## サポートリージョン

### 利用可能リージョン
- us-east-1 (バージニア北部)
- us-east-2 (オハイオ)
- us-west-2 (オレゴン)
- **ap-northeast-1 (東京)** ✅
- ap-south-1 (ムンバイ) *
- ap-northeast-2 (ソウル)
- ap-southeast-1 (シンガポール)
- ap-southeast-2 (シドニー)
- ca-central-1 (カナダ中部)
- eu-west-1 (アイルランド)
- eu-west-2 (ロンドン)
- eu-west-3 (パリ) **
- eu-central-1 (フランクフルト)
- eu-north-1 (ストックホルム)
- sa-east-1 (サンパウロ)

*ap-south-1: OpensearchInstanceType = c6g.large.search
**eu-west-3: OpensearchInstanceType = m5.large.search

## AWS リージョンインポート

### Global リソース（アカウント毎に1回）
- IAM ロール (WorkloadDiscoveryRole)

### Regional リソース（リージョン毎）
- AWS Config配信チャネル
- AWS Config用S3バケット
- IAM ロール (ConfigRole)

### インポート方法
1. **AWS CloudFormation StackSets**（推奨）
2. **AWS CloudFormation**（個別）

## セキュリティ設計

### 認証・認可
- **Amazon Cognito**ユーザープール
- **JSON Web Token (JWT)**認証
- **IAM ロール**ベースアクセス制御

### ネットワークセキュリティ
- **Amazon VPC**内デプロイ
- **セキュリティグループ**による通信制御
- **VPCエンドポイント**使用（可能な場合）

### データ暗号化
- **保管時暗号化**: AWS KMS
- **転送時暗号化**: TLS
- **ノード間暗号化**: OpenSearch Service

## コスト機能設定

### AWS Cost and Usage Report (CUR)
```bash
# レポート名規則
workload-discovery-cost-and-usage-<account-ID>

# 必須設定
- リソースIDのインクルード: 有効
- レポートパスプレフィックス: workload-discovery
- 時間単位: 日別
- データ統合: Amazon Athena
```

### S3レプリケーション（他アカウントCUR用）
- 送信先: CostAndUsageReportBucket
- オブジェクト所有者変更: 有効

## サポートリソース

### AWS Config対応リソース
- 全AWS Configサポートリソース

### 追加対応リソース（SDK経由）
- AWS::ApiGateway::Authorizer
- AWS::ApiGateway::Resource  
- AWS::ApiGateway::Method
- AWS::Cognito::UserPool
- AWS::ECS::Task
- AWS::EKS::Nodegroup
- AWS::IAM::AWSManagedPolicy
- AWS::ElasticLoadBalancingV2::TargetGroup
- AWS::EC2::Spot
- AWS::EC2::SpotFleet

## トラブルシューティング

### よくある問題
1. **ConfigAggregatorエラー**: AlreadyHaveConfigSetup = Yes
2. **OpenSearchServiceロールエラー**: CreateOpensearchServiceRole = No
3. **レプリケーション失敗**: IAMロール権限確認

### 必要なS3レプリケーション権限
```json
[
  "s3:ReplicateObject",
  "s3:ReplicateDelete", 
  "s3:ReplicateTags",
  "s3:ObjectOwnerOverrideToBucketOwner",
  "s3:ListBucket",
  "s3:GetReplicationConfiguration",
  "s3:GetObjectVersionForReplication",
  "s3:GetObjectVersionAcl",
  "s3:GetObjectVersionTagging",
  "s3:GetObjectRetention",
  "s3:GetObjectLegalHold"
]
```

## 運用ベストプラクティス

### 推奨構成
- **専用AWSアカウント**でのデプロイ
- **複数インスタンス構成**（本番環境）
- **Amazon Cognito高度なセキュリティ**有効化
- **ライフサイクルポリシー**設定（90日）

### 監視・メトリクス
- **匿名使用状況メトリクス**: オプション
- **CloudWatch Logs**: ECSタスクログ
- **15分間隔**でのリソース検出

## アンインストール

### 事前作業
1. **Amazon ECSクラスター**の全タスク停止

### 削除方法
```bash
# AWS CLI
aws cloudformation delete-stack --stack-name <stack-name>

# または AWS Management Console
CloudFormation > スタック選択 > 削除
```

## 企業レベル設計ポイント

### スケーラビリティ
- **マルチアカウント対応**
- **マルチリージョン対応**
- **StackSets活用**

### 可用性
- **マルチAZ構成**オプション
- **Neptune読み取りレプリカ**
- **OpenSearch複数インスタンス**

### コスト最適化
- **インスタンスタイプ選択**
- **ライフサイクルポリシー**
- **AWS Cost Explorer**活用

---
**実装ガイド**: CloudFormationテンプレート必須
**デプロイ時間**: 約30分
**最終更新**: 2022年11月（v2.0.1）