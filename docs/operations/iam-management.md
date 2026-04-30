# IAM権限管理

この文書を IAM Role 一覧の正本とします。Role ごとの詳細設計は必要な時だけ個別文書に分け、通常はこの文書の Role カタログで用途・Assume元・権限方針を管理します。

PR terraform plan 用 Role の詳細設計補足は [pr-terraform-plan-role-design.md](./pr-terraform-plan-role-design.md) に分けています。

## Roleカタログ

Role名、Assume元、権限方針、管理場所はこの表を正本にします。図は更新漏れが起きやすいため、この文書では管理しません。

| Role | 用途 | Assume元 | 権限方針 | 管理 |
| --- | --- | --- | --- | --- |
| `HannibalDeveloperRole-Dev` | 開発者の手元作業 | `hannibal` IAM User | dev作業用の広い開発権限 | `terraform/foundation`。厳密運用で変更 |
| `HannibalCICDRole-Dev` | main の deploy / destroy | GitHub Actions OIDC `repo:kmryst/terraform-hannibal:ref:refs/heads/main` | deploy / destroy 用。PR plan には使わない | `terraform/foundation`。最小権限化の現状確認は #129 |
| `HannibalPRPlanRole-Dev` | PR の `terraform plan` | GitHub Actions OIDC `repo:kmryst/terraform-hannibal:pull_request` | read-only plan。apply / destroy / write 系権限なし | #121 で設計、#127 で実装予定。詳細は [pr-terraform-plan-role-design.md](./pr-terraform-plan-role-design.md) |
| `nestjs-hannibal-3-ecs-task-execution-role` | ECS Task の起動、ECR pull、CloudWatch Logs、RDS managed secret参照 | `ecs-tasks.amazonaws.com` | ECS実行に必要な権限だけ。Secrets Manager read はprefixで絞る | `terraform/environments/dev` 経由のアプリケーションTerraform |
| `nestjs-hannibal-3-codedeploy-service-role` | CodeDeploy Blue/Green | `codedeploy.amazonaws.com` | AWS managed `AWSCodeDeployRoleForECS` | `terraform/environments/dev` 経由のアプリケーションTerraform |
| `CacooAWSIntegrationRole` | Cacoo構成図連携 | Cacoo AWS Account | 構成図生成用read-only | `terraform/foundation` |

## 🔐 IAM構成 (AWS Professional設計)

### **基盤IAMリソース**
```
👤 hannibal (IAMユーザー・メイン開発者)
├── インラインポリシー: AssumeDevRole
└── 使用可能ロール: HannibalDeveloperRole-Dev
   └── アタッチポリシー: HannibalDeveloperPolicy-Dev（ECR/ECS/RDS/CloudWatch/EC2/ELB/S3/CloudFront/IAM）

🤖 GitHub Actions OIDC (main branch deploy / destroy)
└── 使用可能ロール: HannibalCICDRole-Dev
   ├── Permission Boundary: HannibalCICDBoundary
   └── アタッチポリシー: HannibalCICDPolicy-Dev

🧪 GitHub Actions OIDC (pull_request terraform plan)
└── 使用予定ロール: HannibalPRPlanRole-Dev
   └── アタッチ予定ポリシー: PR plan用read-only policy

🗺️ Cacoo AWS Integration
└── 使用可能ロール: CacooAWSIntegrationRole
   └── アタッチポリシー: CacooReadOnlyPolicy
```

### **アプリケーションIAMリソース（一時的・Terraform管理）**
```
🔧 ecs-tasks.amazonaws.com (ECSサービス)
└── 使用ロール: nestjs-hannibal-3-ecs-task-execution-role（Terraform管理）
   ├── Permission Boundary: HannibalECSBoundary（現在永続化・検討の余地あり）
   ├── アタッチポリシー: AmazonECSTaskExecutionRolePolicy（AWS管理ポリシー・Terraformでアタッチ）
   └── アタッチポリシー: nestjs-hannibal-3-ecs-task-execution-secrets-manager-read

🚦 codedeploy.amazonaws.com (Blue/Greenデプロイ)
└── 使用ロール: nestjs-hannibal-3-codedeploy-service-role（Terraform管理）
   └── アタッチポリシー: AWSCodeDeployRoleForECS（AWS管理ポリシー）
```

### **運用フロー**
```bash
# 日常開発 (hannibal)
aws sts assume-role --role-arn arn:aws:iam::258632448142:role/HannibalDeveloperRole-Dev --role-session-name dev-session

# 自動deploy / destroy (GitHub Actions main)
# GitHub OIDCでHannibalCICDRole-DevをAssumeRoleWithWebIdentity

# PR terraform plan (GitHub Actions pull_request, #127/#122実装後)
# GitHub OIDCでHannibalPRPlanRole-DevをAssumeRoleWithWebIdentity
```

### **管理方針**
- **IAMユーザー**: 完全手動管理
- **基盤IAMロール・ポリシー**: `terraform/foundation` で扱い、厳密運用で変更する
- **アプリケーションIAMロール・ポリシー**: `terraform/environments/dev` から作成・破棄される
- **段階的権限縮小**: CloudTrailログ分析とPRレビューで継続的に行う

## 🏗️ 設計原則

### 基盤とアプリケーションの分離
- **基盤IAMリソース**: 永続保持し、変更時は厳密運用で扱う
- **アプリケーションIAMリソース**: Terraform管理・一時的

### 最小権限の原則
- **CloudTrail分析**: 実際の使用権限を特定する
- **Permission Boundary**: 最大権限の制限
- **段階的権限縮小**: 過去分析を起点に、現状確認と縮小を継続する

### 環境分離
- **開発環境**: HannibalDeveloperRole-Dev
- **deploy / destroy環境**: HannibalCICDRole-Dev
- **PR plan環境**: HannibalPRPlanRole-Dev
- **本番環境**: 将来的に別アカウント分離

## 📊 権限最適化結果

### CI/CD権限分析 2025年7月27日（過去分析）
- **分析前**: 160個の権限
- **実際使用**: 76個の権限
- **削減率**: 52%の権限削減達成

現在の `HannibalCICDRole-Dev` の実権限と最小権限化は #129 で再確認します。PR plan ではこのRoleを流用せず、`HannibalPRPlanRole-Dev` を分けることを正とします。

### 企業レベル監査
- **CloudTrail**: 全API呼び出しを記録
- **Athena分析**: 権限使用パターンの可視化
- **継続的最適化**: 定期的な権限見直し

## 🔒 セキュリティ機能

### Permission Boundary
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": [
        "iam:CreateUser",
        "iam:DeleteUser",
        "organizations:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### Trust Policy例

GitHub Actions main の deploy / destroy 用:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::258632448142:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:kmryst/terraform-hannibal:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

PR terraform plan 用のTrust Policyは [pr-terraform-plan-role-design.md](./pr-terraform-plan-role-design.md) で扱います。

## 🔧 運用手順

### 権限追加プロセス
1. **要件定義**: 必要な権限を明確化
2. **最小権限検証**: 本当に必要な権限のみを特定
3. **Permission Boundary確認**: 境界内での権限追加
4. **CloudTrail監視**: 追加後の使用状況を監視

### 権限削除プロセス
1. **使用状況分析**: Athenaで実際の使用を確認
2. **影響範囲調査**: 削除による影響を評価
3. **段階的削除**: テスト環境での検証後に本番適用
4. **継続監視**: 削除後の動作確認

### 定期メンテナンス
- **月次権限レビュー**: 使用されていない権限の特定
- **四半期最適化**: Permission Boundaryの見直し
- **年次監査**: 全体的なIAM構成の見直し
