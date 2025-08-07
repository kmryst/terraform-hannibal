# AWS Workload Discovery on AWS Rules

## 概要
AWS Workload Discovery on AWSは、AWSクラウドのワークロードをアーキテクチャ図として自動的に可視化するソリューションです。

## 動作確認済み環境
- **バージョン**: v2.3.2 (最新版)
- **デプロイ環境**: nestjs-hannibal-3
- **確認日**: 2025年8月7日
- **デプロイ状況**: ✅ CloudFormationスタック作成成功
- **構成図作成**: ❌ ECR API接続エラーで未達成
- **企業実装事例**: DMM.com、SWX社で運用実績あり（別環境）

## 重要な前提条件

### 1. デプロイ方法
- **標準のAWS CLIコマンドは存在しない**
- **CloudFormationテンプレートを使用した正式デプロイが必須**
- 専用のCLIツールではなく、CloudFormationベースのソリューション

### 2. 必要な前提条件
- **AWS Config**が設定されていることが必須
- **AWSServiceRoleForAmazonOpenSearchService**ロールの確認
- **専用AWSアカウント**での運用を推奨（理想的構成）

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
| パラメータ | デフォルト | 推奨設定 | 説明 |
|-----------|-----------|----------|------|
| AdminUserEmailAddress | 必須入力 | - | 初期ユーザーのメールアドレス（認証情報送信先） |
| AlreadyHaveConfigSetup | No | **Yes** ✅ | AWS Config設定済みかどうか（既存Config使用推奨） |
| VpcId | '' | **既存VPC ID** ✅ | 既存VPC使用でネットワーク問題回避 |
| CreateOpenSearchServiceRole | Yes | **No** ✅ | OpenSearchServiceロール作成要否（既存ロール使用） |
| DiscoveryTaskFrequency | 24hrs | **15mins** ⚡ | リソース検出間隔（24時間待機問題回避） |
| NeptuneInstanceClass | db.r7g.large | db.t4g.medium | Neptuneインスタンスタイプ（コスト最適化） |
| OpensearchInstanceType | m6g.large.search | t3.small.search | OpenSearchインスタンスタイプ（コスト最適化） |
| CreateNeptuneReplica | No | No | Neptune読み取りレプリカ作成（高可用性） |
| OpensearchMultiAz | No | No | OpenSearchマルチAZ配置（高可用性） |

## 実証結果（nestjs-hannibal-3での検証）

### デプロイフェーズ
- **CloudFormationテンプレート**: 正常実行 ✅
- **25個のネストされたスタック**: 作成完了 ✅
- **AWS Config設定**: 正常完了 ✅
- **所要時間**: 約30分

### 運用フェーズ
- **Import Accounts**: 手動設定完了 ✅
- **ECSタスク実行**: ECR API接続エラー ❌
- **エラーメッセージ**: "The discovery component encountered an issue connecting to the ECR API endpoint"
- **構成図作成**: 未達成 ❌

### 削除フェーズ
- **理由**: 月額425 USDのコスト + 問題解決困難
- **削除実行**: destroy.ps1で正常削除 ✅

## 実際に発生した問題と対処（2025年8月7日）

### ECR API接続エラー（実証済み問題）
**現象**：
```
The discovery component encountered an issue connecting to the ECR API endpoint.
```

**調査結果**：
- ECR VPCエンドポイント: ✅ 自動作成済み
- セキュリティグループ: ⚠️ 設定不備の可能性
- ルートテーブル: ⚠️ 接続経路問題の可能性

**試行した対処法**：
1. ECSタスク手動実行 → 同じエラーで失敗 ❌
2. 24時間待機設定 → 長期コスト発生のため断念 ❌

**未検証の改善案**：
- 既存VPC使用（VpcId指定）
- 既存AWS Config活用（AlreadyHaveConfigSetup: Yes）
- 15分間隔設定（DiscoveryTaskFrequency: 15mins）

### 根本原因の分析
```
新規VPC作成 → 複雑なネットワーク設定 → ECR API接続失敗
```

**理論的な解決策**：
```
既存VPC使用 → 設定済み環境 → ネットワーク問題回避
```

## 次回実行時の改善手順

### Phase 1: 準備（5分）
```bash
# 既存VPC ID取得
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=nestjs-hannibal-3*" --query "Vpcs[0].VpcId" --output text)
echo "VPC ID: $VPC_ID"

# AWS Config状況確認
aws configservice describe-configuration-recorders

# VPCエンドポイント確認
aws ec2 describe-vpc-endpoints --filters "Name=service-name,Values=*ecr*"
```

### Phase 2: 修正パラメータでデプロイ（30分）
```yaml
# workload-discovery-optimized.yaml
Parameters:
  VpcId: !Ref VPC_ID
  AlreadyHaveConfigSetup: 'Yes'
  DiscoveryTaskFrequency: '15mins'
  CreateOpensearchServiceRole: 'No'
  NeptuneInstanceClass: 'db.t4g.medium'
  OpensearchInstanceType: 't3.small.search'
```

### Phase 3: 構成図作成（60分）
- Import Accounts
- 15分待機でリソース検出
- Create diagram
- Export完了

### Phase 4: 即座削除（15分）
```bash
aws cloudformation delete-stack --stack-name workload-discovery-stack
```

## コスト情報

### 単一インスタンス構成（デフォルト）
- **時間あたり**: 約0.58 USD
- **月額**: 約425.19 USD
- **主要コスト**: Amazon Neptune (254.04 USD/月)

### 実証済み運用戦略

#### 失敗パターン（実際に発生）
```
新規VPC作成 → 複雑なネットワーク設定 → ECR API接続失敗 → 構成図作成不可
```

#### 推奨改善パターン（未検証）
```
既存VPC使用 → 設定済み環境活用 → ネットワーク問題回避 → 構成図作成成功（予想）
```

### コスト実績と戦略
- **デプロイ期間**: 約2時間
- **実際コスト**: 約1-2 USD
- **構成図作成**: 未達成のため効果測定不可

### 推奨: 短期利用型
```bash
# 1-2時間の短期利用パターン（推奨）
総時間: デプロイ(30分) + 構成図作成(60分) + 削除(15分) = 105分
実質コスト: 425 USD × (105分/43800分) ≈ 1-2 USD
削減率: 99%
```

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

## VPC設定に関する考慮事項

### 理想的な構成（AWS推奨）
```
専用管理アカウント: Workload Discovery on AWS
├── 新規VPC (専用環境) ✅ 理想的
├── 適切なセキュリティ設計
└── 独立したネットワーク環境

分析対象アカウント: nestjs-hannibal-3等
└── 既存VPC (分析対象)
```

### 実用的な構成（問題回避型）
```
既存VPC使用: ネットワーク問題回避
├── 設定済みVPCエンドポイント活用 ✅
├── 実証済みのネットワーク環境 ✅
└── ECR接続が既に動作している環境 ✅
```

### 設定選択の判断基準
- **理想**: 専用アカウント + 新規VPC（AWS推奨・セキュリティベストプラクティス）
- **現実**: 既存VPCでの「とりあえず動く」実用性重視
- **短期利用**: 既存VPCでの問題回避が現実的
- **本格運用**: 専用アカウントでの新規VPCを検討

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

## トラブルシューティング

### 実証済み問題とその対処法

#### 1. ECR API接続エラー（重要）
```
エラー: "The discovery component encountered an issue connecting to the ECR API endpoint"
原因: 新規VPC作成時のネットワーク設定問題
対処: 既存VPC使用（VpcId指定）で回避可能
```

#### 2. リソース検出の24時間遅延
```
設定: DiscoveryTaskFrequency: '24hrs'
問題: Import Accounts後、24時間待機が必要
対処: '15mins'設定で即座利用可能
```

#### 3. 高額な運用コスト
```
問題: 月額425 USD継続課金
対処: 短期利用パターンで99%コスト削減
```

### よくある問題
1. **ConfigAggregatorエラー**: AlreadyHaveConfigSetup = Yes
2. **OpenSearchServiceロールエラー**: CreateOpensearchServiceRole = No
3. **レプリケーション失敗**: IAMロール権限確認
4. **インポート中アクセス不可**: 次回検出まで一時的に利用不可
5. **Deployment Healthcheck Errors**: ネットワーク接続問題

## 運用ベストプラクティス

### 実証に基づく推奨構成

#### パターン1: 既存インフラ活用型（推奨）
```yaml
# ネットワーク問題回避のための設定
AlreadyHaveConfigSetup: 'Yes'    # 既存Config使用
VpcId: 'vpc-xxxxxxxx'            # 既存VPC指定
CreateOpensearchServiceRole: 'No' # 既存ロール活用
DiscoveryTaskFrequency: '15mins'  # 即座利用のため
```

#### パターン2: 短期利用型（コスト最適化）
```bash
# 1-2時間の短期利用戦略
1. 最適設定でデプロイ（30分）
2. アーキテクチャ図作成（60分）
3. 即座に削除（15分）
# 総コスト: 1-2 USD（99%削減）
```

### 企業運用での推奨事項
- **共有運用**: 1つのソリューションを複数プロジェクトで活用
- **定期利用**: アーキテクチャ図更新時の定期実行
- **新人研修**: システム全体把握の教育ツールとして活用
- **無駄リソース検出**: 定期的なリソース棚卸しに活用

### 事前準備のチェックリスト
```bash
# 1. 既存VPCエンドポイント確認
aws ec2 describe-vpc-endpoints --filters "Name=service-name,Values=*ecr*"

# 2. AWS Config状況確認
aws configservice get-configuration-recorders

# 3. IAM権限確認
aws sts get-caller-identity
aws iam get-role --role-name workload-discovery-role 2>/dev/null
```

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

## 実用性評価

### ✅ 確認済みの動作
- **デプロイ成功**: CloudFormationテンプレートは正常動作
- **AWS Config連携**: 設定とリソース検出は正常
- **WebUI表示**: 認証・ダッシュボード表示は正常

### ❌ 未達成の機能
- **リソース検出**: ECR API接続エラーで失敗
- **構成図作成**: 上記問題により未達成
- **実用性確認**: 核心機能が動作しないため評価不可

### ⚠️ 実証できていない項目
- 構成図の品質・精度
- 手動調整の必要性
- エクスポート機能
- 実際の運用コスト効果

### 企業事例での利用価値（参考）
- **短時間作成**: 30分程度で最新アーキテクチャ図完成
- **理解度向上**: 対象システムへの理解度が低いメンバーでも図作成可能
- **無駄リソース検出**: システム内の不要リソース発見
- **関係性可視化**: 複雑なリソース間の関係を自動描画

### 注意点・制約
- **高運用コスト**: 月額約425 USD（デフォルト構成）
- **手動調整必須**: 自動生成後の見やすさ調整が必要
- **Ctrl+Z未対応**: WebUI上での編集取り消し不可
- **複雑性**: 全リソース表示時の図の複雑化

## アンインストール

### 事前作業
1. **Amazon ECSクラスター**の全タスク停止

### 削除方法
```bash
# AWS CLI
aws cloudformation delete-stack --stack-name 

# または AWS Management Console
CloudFormation > スタック選択 > 削除
```

## 結論と推奨事項

### 現状の評価
- **デプロイ**: 技術的には成功するが、ネットワーク設定に課題
- **構成図作成**: 核心機能が未達成のため実用性未確認
- **コスト**: 短期利用戦略により大幅削減可能

### 次回実行時の推奨
1. **既存VPCを活用**したネットワーク問題の回避
2. **15分間隔設定**での即座利用
3. **短期利用パターン**でのコスト最適化
4. **構成図作成完了後の即座削除**

### 本格運用時の考慮事項
- **専用アカウント + 新規VPC**が理想的な構成
- **企業事例**では実際に価値を発揮している
- **ネットワーク設定の課題**が解決すれば有用なツール

---
**実装ガイド**: CloudFormationテンプレート必須
**デプロイ時間**: 約30分
**構成図作成**: ECR API接続エラーで未達成（2025年8月7日現在）
**企業実装事例**: DMM.com、SWX社で運用実績（別環境）
**最終更新**: 2025年8月7日（実証結果反映版）

[1] https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/25661301/c5886361-8d95-475f-8333-3e8f6a402b6f/aws-workload-discovery-rules.md