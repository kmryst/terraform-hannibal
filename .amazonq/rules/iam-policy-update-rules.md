# IAMポリシー更新ルール（Professional設計）

## 基本原則
- **基盤IAMリソースは手動管理**（Terraform管理外）
- **JSONファイルとiam.tfの両方を更新**して一貫性を保つ
- **バージョン上限（5個）を考慮**した更新手順

## 更新手順

### 1. ファイル更新
```
terraform\foundation\HannibalCICDPolicy-Dev-Minimal.json
terraform\foundation\iam.tf
```
両方に同じ権限を追加

### 2. 現在のバージョン確認
```powershell
aws iam list-policy-versions --policy-arn arn:aws:iam::258632448142:policy/HannibalCICDPolicy-Dev-Minimal
```

### 3. 古いバージョン削除（5個の場合）
```powershell
aws iam delete-policy-version --policy-arn arn:aws:iam::258632448142:policy/HannibalCICDPolicy-Dev-Minimal --version-id v[最古のバージョン]
```

### 4. 新バージョン作成
```powershell
aws iam create-policy-version --policy-arn arn:aws:iam::258632448142:policy/HannibalCICDPolicy-Dev-Minimal --policy-document file://terraform/foundation/HannibalCICDPolicy-Dev-Minimal.json --set-as-default
```

## 対象ポリシー
- **HannibalCICDPolicy-Dev-Minimal**: CI/CD用最小権限
- **HannibalDeveloperPolicy-Dev**: 開発用統合権限

## 企業レベルの管理方針
- ✅ **Infrastructure as Code**: コードと実環境の一致
- ✅ **バージョン管理**: 変更履歴の追跡
- ✅ **最小権限**: CloudTrail分析に基づく権限設計
- ✅ **監査対応**: 全変更をGitで記録

## 注意事項
- **Terraform管理外**: destroy時も削除されない
- **Permission Boundary**: 権限制限は維持
- **CloudTrail記録**: 全権限変更が監査ログに記録