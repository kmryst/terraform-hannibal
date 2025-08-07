# AWS Workload Discovery on AWS Rules

## 概要
AWS Workload Discovery on AWSは、AWSクラウドのワークロードをアーキテクチャ図として自動的に可視化するソリューションです。

## 動作確認済み環境
- **バージョン**: v2.3.2 (最新版)
- **実装プロジェクト**: nestjs-hannibal-3
- **確認日**: 2025年8月6日
- **動作状況**: ✅ 完全動作確認済み
- **企業実装事例**: DMM.com、SWX社で運用実績あり

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
| AdminUserEmailAddress | 必須入力 | 初期ユーザーのメールアドレス（認証情報送信先） |
| AlreadyHaveConfigSetup | No | AWS Config設定済みかどうか |
| CreateOpenSearchServiceRole | Yes | OpenSearchServiceロール作成要否 |
| NeptuneInstanceClass | db.r7g.large | Neptuneインスタンスタイプ（v2.3.2最新） |
| OpensearchInstanceType | m6g.large.search | OpenSearchインスタンスタイプ |
| CreateNeptuneReplica | No | Neptune読み取りレプリカ作成（高可用性） |
| OpensearchMultiAz | No | OpenSearchマルチAZ配置（高可用性） |
| DiscoveryTaskFrequency | 15mins | リソース検出間隔（15分/1時間/2時間等） |

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

## 企業運用での実践知見

### DMM.com運用事例
- **導入目的**: 手動アーキテクチャ図作成の自動化
- **運用体制**: 1つのソリューションを複数プロジェクトで共有
- **作成時間**: 30分程度でアーキテクチャ図完成
- **効果**: システム理解度向上、無駄リソース検出

### SWX社運用事例
- **検証バージョン**: v2.1.6
- **デプロイ時間**: 30分〜1時間
- **利用シーン**: 複雑環境の構成図作成、新メンバーのシステム把握

## アーキテクチャ図作成の実践手順

### 1. リソースインポート
```bash
# 対象アカウント・リージョンを指定
# CloudFrontなどグローバルサービス含む場合は「US East (N. Virginia)」も選択
# インポート後、15分間隔でリソース検出実行
```

### 2. Diagram作成の推奨手順
```
1. Resources画面で対象アカウント・リージョン選択
2. グローバルサービス含む場合は「global」も選択
3. 推奨リソースタイプ選択:
   - AWS::EC2::VPC
   - AWS::CloudFront::Distribution
4. 「Add to diagram」で関連リソース自動追加
5. Visibility（Private/Public）とName設定
```

### 3. Diagram最適化
```
# 非表示推奨リソースタイプ
- AWS::EC2::NetworkInterface
- AWS::EC2::SecurityGroup  
- AWS::ECS::Task
- AWS::RDS::DBClusterSnapshot
- AWS::Tags::Tag
```

### 4. エクスポート・手動調整
```
# 推奨エクスポート形式
- Draw.io形式（手直しが容易）
- JSON、CSV形式も対応

# 手動調整が必要な項目
- 枠線の重なり修正
- リソース配置の最適化
- リソース名の可読性向上
```

## WebUI操作ガイド

### Diagram編集機能
| 機能 | 説明 |
|------|------|
| Expand | 選択リソースに紐づくリソースを図に追加 |
| Focus | 選択リソースに紐づくリソースのみ表示 |
| Remove | 選択リソースを削除 |
| Group | リソースタイプでグループ化・矢印線削除 |
| Fit | 構成図を中央表示 |
| Clear | 構成図を全削除 |
| Export | 構成図エクスポート |

### 認証情報の受信
- **送信元**: no-reply@verificationemail.com
- **内容**: ユーザー名・パスワード
- **注意**: AdminUserEmailAddressに有効なメールアドレス必須

## トラブルシューティング

### よくある問題
1. **ConfigAggregatorエラー**: AlreadyHaveConfigSetup = Yes
2. **OpenSearchServiceロールエラー**: CreateOpensearchServiceRole = No
3. **レプリケーション失敗**: IAMロール権限確認
4. **リソース検出遅延**: 15分間隔実行のため最大15分待機
5. **インポート中アクセス不可**: 次回検出まで一時的に利用不可

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

### 企業運用での推奨事項
- **共有運用**: 1つのソリューションを複数プロジェクトで活用
- **定期利用**: アーキテクチャ図更新時の定期実行
- **新人研修**: システム全体把握の教育ツールとして活用
- **無駄リソース検出**: 定期的なリソース棚卸しに活用

### コスト最適化（実践版）
```bash
# 使用しない期間のコスト削減
1. ECSタスクスケジュール無効化
2. Neptuneクラスター停止

# インスタンスタイプ最適化
- NeptuneInstanceClass: db.t4g.medium（開発環境）
- OpensearchInstanceType: t3.small.search（開発環境）
```

### 監視・メトリクス
- **匿名使用状況メトリクス**: オプション
- **CloudWatch Logs**: ECSタスクログ
- **15分間隔**でのリソース検出（毎時00分、15分、30分、45分）

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

## 実用性評価

### ✅ 使ってよかった点
- **短時間作成**: 30分程度で最新アーキテクチャ図完成
- **理解度向上**: 対象システムへの理解度が低いメンバーでも図作成可能
- **無駄リソース検出**: システム内の不要リソース発見
- **関係性可視化**: 複雑なリソース間の関係を自動描画

### ⚠️ 注意点・制約
- **高運用コスト**: 月額約425 USD（デフォルト構成）
- **手動調整必須**: 自動生成後の見やすさ調整が必要
- **Ctrl+Z未対応**: WebUI上での編集取り消し不可
- **複雑性**: 全リソース表示時の図の複雑化

### 💡 活用シーン
- **アーキテクチャ図のたたき台作成**
- **新メンバーのシステム全体把握**
- **複雑環境の構成確認**
- **定期的なリソース棚卸し**

---
**実装ガイド**: CloudFormationテンプレート必須
**デプロイ時間**: 約30分
**企業実装事例**: DMM.com、SWX社で運用実績
**最終更新**: 2025年8月6日（v2.3.2対応）