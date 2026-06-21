# 事前準備

## **⚠️ 重要: GitHub Actions実行前の準備**

GitHub ActionsのCI/CDパイプラインを安定して実行するため、以下のリソースを事前に手動作成してください。

### **1. ECRリポジトリの事前作成**
```bash
# コンテナイメージを保存するECRリポジトリを作成
aws ecr create-repository --repository-name nestjs-hannibal-3 --region ap-northeast-1

# 作成確認
aws ecr describe-repositories --repository-names nestjs-hannibal-3 --region ap-northeast-1
```

### **2. S3バケットの事前作成**
```bash
# フロントエンドの静的ファイルを保存するS3バケットを作成
aws s3 mb s3://nestjs-hannibal-3-frontend --region ap-northeast-1

# 作成確認
aws s3 ls s3://nestjs-hannibal-3-frontend
```

### **3. CloudFront Origin Access Control (OAC) の事前作成**
```bash
# S3バケットへの安全なアクセスを制御するOACを作成
aws cloudfront create-origin-access-control \
  --name nestjs-hannibal-3-oac \
  --origin-access-control-origin-type s3 \
  --signing-behavior always \
  --signing-protocol sigv4 \
  --region us-east-1

# 作成されたOACのIDを確認
aws cloudfront list-origin-access-controls --region us-east-1
```

**重要**: OACのIDを取得後、`terraform/frontend/main.tf`の47行目を更新してください：
```hcl
data "aws_cloudfront_origin_access_control" "s3_oac" {
  id = "取得したOACのID" # E1EA19Y8SLU52Dを実際のIDに置き換え
}
```

## **🔧 手動作成リソース一覧（CI/CD用・Terraform参照）**
| リソース | 名前 | 目的 | 作成方法 | 管理方法 |
|---------|------|------|----------|----------|
| ECRリポジトリ | `nestjs-hannibal-3` | コンテナイメージ保存 | AWS CLI | **手動管理（Terraform参照）** |
| S3バケット | `nestjs-hannibal-3-frontend` | フロントエンド静的ファイル | AWS CLI | **手動管理（Terraform参照）** |
| CloudFront OAC | `nestjs-hannibal-3-oac` | S3バケットへの安全なアクセス | AWS CLI | **手動管理（Terraform参照）** |

**手動作成の理由**: 
- ✅ **権限エラー回避**: GitHub Actions実行時の権限不足エラーを防ぐ
- ✅ **CI/CD安定性**: デプロイパイプラインの安定性向上
- ✅ **実行時間短縮**: リソース作成時間を短縮
- 📝 **注意**: リソース本体は手動管理、Terraformはdataリソースで参照のみ

## **🔒 永続保持リソース（監査・基盤用）**
以下のリソースは**destroy時も削除されず、永続的に保持**されます：

| リソース | 名前 | 目的 | 理由 | 管理方法 |
|---------|------|------|------|----------|
| S3バケット | `nestjs-hannibal-3-terraform-state` | Terraform状態ファイル / S3 lockfile | state backend 本体。Terraform で管理すると、管理対象の state を保存する先も同じ Terraform で作るニワトリと卵の状態になるため | **手動管理** |
| S3バケット | `nestjs-hannibal-3-cloudtrail-logs` | CloudTrail監査ログ | セキュリティ監査 | **Terraform foundation管理** |
| S3バケット | `nestjs-hannibal-3-athena-results` | Athena分析結果 | 権限分析基盤 | **Terraform foundation管理** |
| Athenaテーブル | `cloudtrail_logs_partitioned` | CloudTrail分析 | 権限最適化 | **Terraform管理** |
| Athenaワークグループ | `hannibal-cloudtrail-analysis` | 専用分析環境 | Professional設計 | **Terraform管理** |
| Athenaデータベース | `hannibal_cloudtrail_db` | 論理データ分離 | Professional設計 | **Terraform管理** |

**永続保持の理由**:
- 🔒 **セキュリティ監査**: API呼び出しの証跡保存
- 📊 **権限分析**: 将来の最小権限最適化
- 💰 **コスト最適化**: ストレージ料金は数セント程度
- 📝 **注意**: 意図的な手動管理または `prevent_destroy` により、通常のdestroy対象から外しています

永続リソースの全体一覧（IAM / ECR / Route53 / ACM 含む）は [docs/operations/aws-resources.md](../operations/aws-resources.md) を参照。
Terraform state backend の運用手順は [docs/operations/terraform-runbook.md](../operations/terraform-runbook.md)、state 復元手順は [docs/operations/rollback-plan.md](../operations/rollback-plan.md) を参照。

## ✅ IAM/OIDC設定（完了済み）

このプロジェクトの IAM / OIDC 設定は完了しています。

### 設定済みリソース
- **GitHub Actions OIDC Provider**: `token.actions.githubusercontent.com` — 長期 Access Key 不要
- **HannibalCICDRole-Dev**: deploy/destroy workflow が OIDC で AssumeRoleWithWebIdentity するロール
- **HannibalPRPlanRole-Dev**: PR terraform plan 用ロール（read-only）
- **HannibalCICDPolicy-Dev-compute / storage / deploy**: CI/CD用ポリシー（3分割して attach 中）

> ※ GitHub Actions から AWS への認証は OIDC を使います。AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY の GitHub Secrets 登録は不要です。

## 🔐 Infrastructure as Code原則

### **ECRライフサイクルポリシー**
- ✅ **Terraformで管理**: インフラの設定をコードで管理
- ✅ **変更履歴追跡**: Gitで変更の追跡が可能
- ✅ **環境再現性**: 同じ設定を他環境で再現可能
- ✅ **チーム共有**: 設定内容をコードとして共有
