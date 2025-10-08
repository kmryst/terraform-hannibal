# ECS Native Blue/Green Deployment Rules (nestjs-hannibal-3)

## ❌ ECS Native Blue/Green - 実装断念

### 試行結果
Amazon ECS Native Blue/Green deployments機能をTerraformで実装しようとしたが、以下の理由で断念。

### 技術的制約
- **Terraform Provider制約**: v6.8.0時点でECS Native Blue/Green機能が未提供
- **構文エラー**: `deployment_configuration`ブロックで`Unexpected block`エラーが発生
- **AWS公式リリース**: 2025年7月17日にリリースされたが、Terraformサポートが追いついていない

```hcl
# ❌ 動作しない構文例
deployment_configuration {
  strategy             = "BLUE_GREEN"
  bake_time_in_minutes = 1
}
# Error: Unexpected block
```

### ✅ 採用した代替案: AWS CodeDeploy

**理由**:
- Terraformで完全サポート済み
- Canary/Blue/Greenデプロイメント対応
- 詳細な監視・ロールバック機能

**実装詳細**: [codedeploy-blue-green.md](../../docs/deployment/codedeploy-blue-green.md)

### 将来の検討事項
Terraform ProviderがECS Native Blue/Greenをサポートした際に再評価を検討。
