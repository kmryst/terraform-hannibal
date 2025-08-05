# CacooでAWS構成図を自動生成する設定ガイド

## 概要
CacooのAWS構成図自動描画機能を使用するためのクロスアカウントIAMロール設定手順

## 前提条件
- **自分のAWSアカウント**: <YOUR_AWS_ACCOUNT_ID>
- **CacooのAWSアカウント**: 631054961367
- **対象リージョン**: 任意（例: ap-northeast-1, us-east-1等）

## 設定手順

### 1. 信頼関係ポリシーファイル作成

**Windows (PowerShell)**:
```powershell
$content = '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":"arn:aws:iam::631054961367:root"},"Action":"sts:AssumeRole"}]}'
[System.IO.File]::WriteAllText('trust-policy.json', $content, [System.Text.UTF8Encoding]::new($false))
```

**Mac/Linux (bash)**:
```bash
echo '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":"arn:aws:iam::631054961367:root"},"Action":"sts:AssumeRole"}]}' > trust-policy.json
```

### 2. 権限ポリシーファイル作成

**Windows (PowerShell)**:
```powershell
$content = '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["cloudfront:ListDistributions","ec2:DescribeInstances","ec2:DescribeSecurityGroups","ec2:DescribeSubnets","ec2:DescribeVpcs","ec2:DescribeAvailabilityZones","elasticloadbalancing:DescribeLoadBalancers","elasticloadbalancing:DescribeTargetGroups","elasticloadbalancing:DescribeTargetHealth","elasticache:DescribeCacheSubnetGroups","elasticache:DescribeCacheClusters","rds:DescribeDBInstances","s3:ListAllMyBuckets","s3:GetBucketLocation","sns:ListTopics","sns:GetTopicAttributes","sqs:ListQueues","ec2:DescribeRouteTables","ec2:DescribeNatGateways"],"Resource":["*"]}]}'
[System.IO.File]::WriteAllText('cacoo-policy.json', $content, [System.Text.UTF8Encoding]::new($false))
```

**Mac/Linux (bash)**:
```bash
echo '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["cloudfront:ListDistributions","ec2:DescribeInstances","ec2:DescribeSecurityGroups","ec2:DescribeSubnets","ec2:DescribeVpcs","ec2:DescribeAvailabilityZones","elasticloadbalancing:DescribeLoadBalancers","elasticloadbalancing:DescribeTargetGroups","elasticloadbalancing:DescribeTargetHealth","elasticache:DescribeCacheSubnetGroups","elasticache:DescribeCacheClusters","rds:DescribeDBInstances","s3:ListAllMyBuckets","s3:GetBucketLocation","sns:ListTopics","sns:GetTopicAttributes","sqs:ListQueues","ec2:DescribeRouteTables","ec2:DescribeNatGateways"],"Resource":["*"]}]}' > cacoo-policy.json
```

### 3. IAMロール作成
```bash
aws iam create-role --role-name CacooAWSIntegrationRole --assume-role-policy-document file://trust-policy.json
```

### 4. 権限ポリシー作成
```bash
aws iam create-policy --policy-name CacooReadOnlyPolicy --policy-document file://cacoo-policy.json
```

### 5. ポリシーアタッチ
```bash
aws iam attach-role-policy --role-name CacooAWSIntegrationRole --policy-arn arn:aws:iam::<YOUR_AWS_ACCOUNT_ID>:policy/CacooReadOnlyPolicy
```

## Cacoo設定値
- **ロールARN**: `arn:aws:iam::<YOUR_AWS_ACCOUNT_ID>:role/CacooAWSIntegrationRole`
- **リージョン**: 構成図を作成したいリージョンを選択
- **配置設定**: 「線をつける」を有効
- **MFA設定**: 無効に設定

**重要**: 入力されたロールARNはCacoo内のデータベースをはじめ、いかなる箇所にも保存されません。

## 📊 構成図に反映されるAWSサービス
- EC2
- VPC
- CloudFront
- Availability Zone
- Subnet
- ELB
- ElastiCache
- RDS
- S3
- SNS
- SQS
- ルートテーブル
- NATゲートウェイ

**注意**: リソースが存在しない場合、構成図には表示されません。

## 🔗 サービス間の線の繋がる条件
「線をつける」を有効にした場合、以下の条件でサービス同士が線で繋がります：
- ELBからターゲットの各EC2インスタンス
- CloudFrontからオリジンに設定されているELBやS3バケット
- アクセスが許可されているセキュリティグループ同士の全てのEC2インスタンス

## 📍 リソースの配置
- **「線をつける」有効**: 親子関係を考慮した階層配置
- **「線をつける」無効**: 左上から格子状配置
- **右下配置**: VPC, Subnet, EC2, ELB, CloudFront, ElastiCache, RDS以外のサービス

## ⚠️ よくあるトラブル

### `sts:AssumeRole` エラー
**原因**: External ID条件が厳しすぎる
**解決**: External ID条件を削除してシンプルな信頼関係に変更

```json
// ❌ 失敗パターン
"Condition": {
  "StringEquals": {"sts:ExternalId": "some-id"}
}

// ✅ 成功パターン  
// 条件なしでシンプルに
{
  "Effect": "Allow",
  "Principal": {"AWS": "arn:aws:iam::631054961367:root"},
  "Action": "sts:AssumeRole"
}
```

### ファイルエンコーディング問題
**Windows環境**: UTF-16エンコーディングでエラー
**解決方法**: PowerShellでBOMなしUTF-8作成
```powershell
[System.IO.File]::WriteAllText('file.json', $content, [System.Text.UTF8Encoding]::new($false))
```

**Mac/Linux環境**: 通常は問題なし（UTF-8がデフォルト）

## 🔒 セキュリティ
- **読み取り専用権限**のみ
- **クロスアカウントAssumeRole**で安全な権限委譲
- **最小権限の原則**を適用

---
**作成日**: 2025年8月5日  
**動作確認**: ✅ 完了