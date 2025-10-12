# セキュリティ運用ルール

## 🔒 セキュリティ要件（絶対遵守）

### 秘密情報の絶対禁止

❌ **コミットしてはいけない情報:**
- AWS Access Key / Secret Key
- データベースパスワード（RDSはSecrets Managerで管理）
- Mapbox API Token（環境変数で管理）
- `.env` ファイル（`.gitignore`に追加済み）
- `terraform.tfvars`（`.gitignore`に追加済み）

✅ **正しい管理方法:**
```bash
# 環境変数で管理
export DATABASE_URL="postgresql://..."
export MAPBOX_TOKEN="pk.xxx"

# AWS Secrets Manager使用（本番環境）
aws secretsmanager get-secret-value --secret-id hannibal-db-credentials
```

### IAM最小権限の原則

**IAM構成** (`terraform/foundation/iam.tf`):
```
hannibal (IAM User)
  └─ AssumeRole → HannibalDeveloperRole-Dev (手動操作用)

hannibal-cicd (IAM User)
  └─ AssumeRole → HannibalCICDRole-Dev (GitHub Actions用)
       └─ Permission Boundary: HannibalCICDBoundary
```

**Permission Boundary**: ECS/RDS/S3のみ操作可能、IAM/Billing/GuardDuty は禁止。

### セキュリティスキャン（自動実行）

**GitHub Actions**: `security-scan.yml`
- **CodeQL**: ソースコード脆弱性（SAST）
- **Trivy**: Dockerイメージ脆弱性（SCA）
- **tfsec**: Terraform設定ミス検出（IaC）
- **Gitleaks**: シークレット漏洩検出

**実行タイミング:**
- PR作成時（必須チェック）
- 週次スケジュール実行
- 検出結果は GitHub Security タブへ集約

---
