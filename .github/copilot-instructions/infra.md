# インフラ・CI/CD運用ルール

（copilot-instructions.mdより該当部分をそのまま移植）

- Terraform運用・State管理
- GitHub Actions運用
- Blue/Green/Canaryデプロイ
- コスト最適化
- 文章・構成は一字一句変更せず分割

## 📊 コスト最適化戦略

### 停止運用による大幅コスト削減

**通常稼働時**: 月額 $30-50
- ECS Fargate: 0.25vCPU / 0.5GB ($15-20)
- RDS t4g.micro: ($10-15)
- ALB: ($18)
- NAT Gateway: ($32)

**停止時**: 月額 $5以下
- S3 (Terraform State): ($1)
- CloudTrail: ($2)
- Route53: ($1)
- 基盤リソース: ($1-2)

**停止方法** (`terraform/foundation/billing.tf` 参照):
```bash
# GitHub Actions: destroy.yml で実行
# または手動:
cd terraform/environments/dev
terraform destroy -target=module.compute
terraform destroy -target=module.storage
```

**起動方法**:
```bash
# GitHub Actions: deploy.yml (provisioning モード)
```
