# 事前準備

## **⚠️ 重要: GitHub Actions実行前の準備**

GitHub ActionsのCI/CDパイプラインを安定して実行するため、以下の3つのリソースを事前に手動作成してください。

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

## **🔒 永続保持リソース（監査・基盤用・Terraform管理外）**
以下のリソースは**destroy時も削除されず、永続的に保持**されます：

| リソース | 名前 | 目的 | 理由 | 管理方法 |
|---------|------|------|------|----------|
| S3バケット | `nestjs-hannibal-3-terraform-state` | Terraform状態ファイル | 基盤リソース | **手動管理** |
| S3バケット | `nestjs-hannibal-3-cloudtrail-logs` | CloudTrail監査ログ | セキュリティ監査 | **手動管理** |
| S3バケット | `nestjs-hannibal-3-athena-results` | Athena分析結果 | 権限分析基盤 | **手動管理** |
| Athenaテーブル | `cloudtrail_logs_partitioned` | CloudTrail分析 | 権限最適化 | **Terraform管理** |
| Athenaワークグループ | `hannibal-cloudtrail-analysis` | 専用分析環境 | Professional設計 | **Terraform管理** |
| Athenaデータベース | `hannibal_cloudtrail_db` | 論理データ分離 | Professional設計 | **Terraform管理** |

**永続保持の理由**:
- 🔒 **セキュリティ監査**: API呼び出しの証跡保存
- 📊 **権限分析**: 将来の最小権限最適化
- 💰 **コスト最適化**: ストレージ料金は数セント程度
- 📝 **注意**: Terraform管理外のため、destroy時も自動削除されません

## ✅ IAM権限設定（完了済み）

このプロジェクトのIAM権限設定は完了しています。

### 設定済みリソース
- **HannibalCICDRole-Dev**: CI/CD用IAMロール
- **HannibalCICDPolicy-Dev**: CI/CD用ポリシー（最新版）
- **GitHub Secrets**: AWS認証情報設定済み

> ※ 初回セットアップ時に一時的な高権限が必要でしたが、現在は完了しているため追加作業は不要です。

## 🔐 Infrastructure as Code原則

### **ECRライフサイクルポリシー**
- ✅ **Terraformで管理**: インフラの設定をコードで管理
- ✅ **変更履歴追跡**: Gitで変更の追跡が可能
- ✅ **環境再現性**: 同じ設定を他環境で再現可能
- ✅ **チーム共有**: 設定内容をコードとして共有