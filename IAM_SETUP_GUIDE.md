# GitHub Actions用 IAM権限設定ガイド

## 📋 **概要**
GitHub ActionsでのCI/CD自動デプロイが権限エラーなく動作するよう、hannibalユーザーに必要な権限を事前に設定します。

---

## 🔧 **手順1: 事前準備**

### **作業ディレクトリ移動**
```powershell
cd C:\code\javascript\nestjs-hannibal-3\terraform\backend
```

### **Terraform初期化**
```powershell
terraform init
```

---

## 🔧 **手順2: 一時的権限付与**

### **AWS Management Consoleで実行**
1. **AWS Console** → **IAM** → **Users** → **hannibal**
2. **Permissions**タブ → **Add permissions** → **Attach policies directly**
3. **IAMFullAccess**を検索してアタッチ

### **またはAWS CLIで実行**
```powershell
aws iam attach-user-policy --user-name hannibal --policy-arn arn:aws:iam::aws:policy/IAMFullAccess
```

**🎯 目的**: `iam:CreatePolicy`権限を一時的に付与してカスタムポリシー作成を可能にする

---

## 🔧 **手順3: カスタムポリシー作成・適用**

### **PowerShellでの正しいコマンド**
```powershell
# プラン確認（引用符が重要）
terraform plan -target="aws_iam_policy.hannibal_terraform_policy" -target="aws_iam_user_policy_attachment.hannibal_terraform_policy"

# 適用実行
terraform apply -target="aws_iam_policy.hannibal_terraform_policy" -target="aws_iam_user_policy_attachment.hannibal_terraform_policy" -auto-approve
```

**⚠️ 重要な注意点:**
- PowerShellでは`-target`の値を**引用符で囲む**必要がある
- 引用符なしだと`Too many command line arguments`エラーが発生

---

## 🔧 **手順4: セキュリティ強化**

### **一時的権限の削除**
```powershell
# AWS Consoleで手動、またはCLIで実行
aws iam detach-user-policy --user-name hannibal --policy-arn arn:aws:iam::aws:policy/IAMFullAccess
```

**🎯 目的**: 最小権限原則に従い、不要な強い権限を即座に削除

---

## 📊 **作成されるリソース**

### **カスタムポリシー**
- **名前**: `HannibalInfraAdminPolicy`
- **説明**: Terraform ECS deployment - ECR, CloudWatch, ELB, EC2, ECS, IAM, S3, CloudFront permissions

### **付与される権限**
| サービス | 権限内容 | GitHub Actions対応 |
|----------|----------|-------------------|
| **ECR** | Container Registry管理 | ✅ |
| **CloudWatch Logs** | ログ管理 | ✅ |
| **ELB/ELBv2** | Load Balancer管理 | ✅ 削除権限追加 |
| **EC2** | VPC, Subnet, SG, ENI | ✅ SG作成・削除権限追加 |
| **ECS** | Cluster, Service, Task Definition | ✅ Cluster削除・作成権限追加 |
| **IAM** | Terraform用ロール・ポリシー管理 | ✅ ポリシーバージョン管理追加 |
| **S3** | バケット・オブジェクト操作 | ✅ |
| **CloudFront** | ディストリビューション・キャッシュ無効化 | ✅ |

---

## 🔍 **GitHub Actions対応で追加した権限**

### **ELBv2権限**
- `elbv2:DescribeLoadBalancers`
- `elbv2:DeleteLoadBalancer`
- `elbv2:DescribeTargetGroups`
- `elbv2:DeleteTargetGroup`

### **EC2権限**
- `ec2:CreateSecurityGroup`
- `ec2:DeleteSecurityGroup`
- `ec2:AuthorizeSecurityGroupIngress`
- `ec2:AuthorizeSecurityGroupEgress`
- `ec2:RevokeSecurityGroupIngress`
- `ec2:RevokeSecurityGroupEgress`
- `ec2:CreateTags`

### **ECS権限**
- `ecs:DeleteCluster`
- `ecs:CreateCluster`

### **IAM権限**
- `iam:ListPolicyVersions`
- `iam:CreatePolicyVersion`
- `iam:DeletePolicyVersion`

---

## ✅ **手順完了後の確認**

### **AWS Consoleで確認**
1. **IAM** → **Users** → **hannibal** → **Permissions**
2. **HannibalInfraAdminPolicy**がアタッチされていることを確認
3. **IAMFullAccess**がデタッチされていることを確認

### **GitHub Secrets設定**
以下がリポジトリのSecretsに設定されていることを確認：
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

---

## 🎯 **設計の意図**

### **1. セキュリティ設計**
- **最小権限原則**: 必要な権限のみを統合
- **一時的権限**: 強い権限は最短時間のみ付与
- **Infrastructure as Code**: 権限もコードで管理

### **2. AWS制限への対応**
- **10個制限**: 8つのサービス権限を1つのカスタムポリシーに統合
- **効率的管理**: マネージドポリシーからカスタムポリシーへ移行

### **3. 運用性向上**
- **自動化対応**: GitHub ActionsでのCI/CD準備完了
- **可視性**: 権限内容がコードで明確に管理
- **再現性**: 環境構築の自動化・標準化

---

## 🚀 **次のステップ**

この手順完了後、GitHub ActionsでのCI/CD自動デプロイが権限エラーなく実行できるようになります。

```bash
# GitHub Actions実行
git push origin feature/github-actions
```

権限設定が正しく完了していれば、以下の処理が自動実行されます：
1. テスト実行
2. 既存リソースクリーンアップ
3. Terraform Backend デプロイ
4. Terraform Frontend デプロイ
5. フロントエンドビルド・S3デプロイ
6. CloudFrontキャッシュ無効化
7. Dockerイメージビルド・ECRプッシュ
8. ECSサービス更新
