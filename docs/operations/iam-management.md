# IAM権限管理

この文書を IAM Role 一覧の正本とします。Role ごとの詳細設計は必要な時だけ個別文書に分け、通常はこの文書の Role カタログで用途・Assume元・権限方針を管理します。

PR terraform plan 用 Role の詳細設計補足は [pr-terraform-plan-role-design.md](./pr-terraform-plan-role-design.md) に分けています。

## Roleカタログ

Role名、Assume元、権限方針、管理場所はこの表を正本にします。図は更新漏れが起きやすいため、この文書では管理しません。

| Role | 用途 | Assume元 | 権限方針 | 管理 |
| --- | --- | --- | --- | --- |
| `HannibalDeveloperRole-Dev` | 日常開発・アプリ運用 | `hannibal` IAM User | ECS exec / ログ確認 / ECR push / Secrets 参照 / dev Terraform plan 専用。wildcard 廃止・action 列挙で最小権限化済み（#164）。Boundary `HannibalDeveloperBoundary-Dev` で上限を設定。`Hannibal*` IAM・OIDC・foundation state・CloudTrail / Athena / Budgets は `HannibalFoundationRole-Dev` で扱う | `terraform/foundation`。厳密運用で変更 |
| `HannibalFoundationRole-Dev` | `terraform/foundation` の手動 apply | `hannibal` IAM User | IAM / OIDC / Permission Boundary / CloudTrail / Athena / Glue Data Catalog / GuardDuty / Budgets / foundation state / S3 lockfile / 監査・分析用 S3 bucket 設定 操作用。DynamoDB lock は移行期間中のみ併用。ポリシーは 3 分割（core/state/services）で Terraform 管理し、managed policy の文字数上限に余裕を持たせる。専用 Boundary `HannibalFoundationBoundary-Dev` で foundation 対象サービスに最大権限を制限。Foundation Role は自身の Boundary を更新しない | `terraform/foundation`。厳密運用で変更 |
| `HannibalCloudTrailCloudWatchLogsRole-Dev` | CloudTrail の CloudWatch Logs 配信 | `cloudtrail.amazonaws.com` | `/aws/cloudtrail/nestjs-hannibal-3` への `logs:CreateLogStream` / `logs:PutLogEvents` のみ。専用 Boundary `HannibalCloudTrailCloudWatchLogsBoundary-Dev` で配信権限に制限 | `terraform/foundation`。厳密運用で変更 |
| `HannibalCICDRole-Dev` | main の deploy / destroy | GitHub Actions OIDC `repo:kmryst/terraform-hannibal:ref:refs/heads/main` | deploy / destroy 用。PR plan には使わない。ポリシーは 3 分割（compute/storage/deploy）で Terraform 管理（#166） | `terraform/foundation`。厳密運用で変更 |
| `HannibalPRPlanRole-Dev` | PR の `terraform plan` | GitHub Actions OIDC `repo:kmryst/terraform-hannibal:pull_request` | read-only plan。`terraform plan -lock=false` 前提のため S3 lockfile の write/delete 権限なし。apply / destroy / write 系権限なし。専用 Boundary `HannibalPRPlanBoundary-Dev` で最大権限も read 系に制限 | #127 (PR #140) で実装済み。Boundary は #139 で追加。詳細は [pr-terraform-plan-role-design.md](./pr-terraform-plan-role-design.md) |
| `nestjs-hannibal-3-ecs-task-execution-role` | ECS Task の起動、ECR pull、CloudWatch Logs、RDS managed secret参照 | `ecs-tasks.amazonaws.com` | ECS実行に必要な権限だけ。Secrets Manager read はprefixで絞る。Role 本体と実権限ポリシーは dev 環境管理だが、Permission Boundary `HannibalECSBoundary` は deploy 前から存在する永続ガードレールとして `terraform/foundation` で管理する | `terraform/environments/dev` 経由のアプリケーションTerraform |
| `nestjs-hannibal-3-codedeploy-service-role` | CodeDeploy Blue/Green | `codedeploy.amazonaws.com` | AWS managed `AWSCodeDeployRoleForECS` | `terraform/environments/dev` 経由のアプリケーションTerraform |

## 🔐 IAM構成 (AWS Professional設計)

### **基盤IAMリソース**
```
👤 hannibal (IAMユーザー・メイン開発者)
├── インラインポリシー: AssumeDevRole
└── 使用可能ロール: HannibalDeveloperRole-Dev
   ├── Permission Boundary: HannibalDeveloperBoundary-Dev（#164で追加）
   └── アタッチポリシー: HannibalDeveloperPolicy-Dev（wildcard廃止・action列挙で最小権限化済み）

🧱 hannibal (foundation手動apply)
└── 使用可能ロール: HannibalFoundationRole-Dev
   ├── Permission Boundary: HannibalFoundationBoundary-Dev
   ├── アタッチポリシー: HannibalFoundationPolicy-Dev（IAM / OIDC / Permission Boundary）
   ├── アタッチポリシー: HannibalFoundationStatePolicy-Dev（foundation backend state / lock）
   └── アタッチポリシー: HannibalFoundationServicesPolicy-Dev（Athena / Glue Data Catalog / CloudTrail / CloudWatch Logs / CloudWatch Alarms / SNS / GuardDuty / Budgets / 監査・分析用 S3 bucket 設定）

🕵️ cloudtrail.amazonaws.com (CloudTrail -> CloudWatch Logs)
└── 使用ロール: HannibalCloudTrailCloudWatchLogsRole-Dev
   ├── Permission Boundary: HannibalCloudTrailCloudWatchLogsBoundary-Dev
   └── インラインポリシー: CloudTrailCloudWatchLogsDelivery（CloudTrail log stream への write のみ）

🤖 GitHub Actions OIDC (main branch deploy / destroy)
└── 使用可能ロール: HannibalCICDRole-Dev
   ├── Permission Boundary: HannibalCICDBoundary（Terraform管理・#166）
   ├── アタッチポリシー: HannibalCICDPolicy-Dev-compute（EC2/VPC・ECR・ECS・ELB）
   ├── アタッチポリシー: HannibalCICDPolicy-Dev-storage（S3・RDS・DynamoDB・SecretsManager・KMS）
   └── アタッチポリシー: HannibalCICDPolicy-Dev-deploy（CloudWatch・CloudFront・Route53・CodeDeploy・SNS・CloudTrail・IAM）

🧪 GitHub Actions OIDC (pull_request terraform plan)
└── 使用中ロール: HannibalPRPlanRole-Dev
   ├── Permission Boundary: HannibalPRPlanBoundary-Dev
   └── アタッチポリシー: HannibalPRPlanPolicy-Dev

```

### **アプリケーションIAMリソース（一時的・Terraform管理）**
```
🔧 ecs-tasks.amazonaws.com (ECSサービス)
└── 使用ロール: nestjs-hannibal-3-ecs-task-execution-role（Terraform管理）
   ├── Permission Boundary: HannibalECSBoundary（foundation管理の永続ガードレール）
   ├── アタッチポリシー: AmazonECSTaskExecutionRolePolicy（AWS管理ポリシー・Terraformでアタッチ）
   └── アタッチポリシー: nestjs-hannibal-3-ecs-task-execution-secrets-manager-read

🚦 codedeploy.amazonaws.com (Blue/Greenデプロイ)
└── 使用ロール: nestjs-hannibal-3-codedeploy-service-role（Terraform管理）
   └── アタッチポリシー: AWSCodeDeployRoleForECS（AWS管理ポリシー）
```

### **運用フロー**
```bash
# 日常開発・アプリ運用 (hannibal)
aws sts assume-role --role-arn arn:aws:iam::<account-id>:role/HannibalDeveloperRole-Dev --role-session-name dev-session

# #164 candidate 検証 (hannibal)
# IAM User 側の AssumeDevRole が既存 Role ARN のみ許可している場合は、
# 検証期間中だけ candidate Role ARN も許可する。
aws sts assume-role --role-arn arn:aws:iam::<account-id>:role/HannibalDeveloperRole-Dev-candidate --role-session-name dev-candidate-session

# terraform/foundation 手動 apply (hannibal)
# HannibalDeveloperRole-Dev では実行しない
aws sts assume-role --role-arn arn:aws:iam::<account-id>:role/HannibalFoundationRole-Dev --role-session-name foundation-apply-session

# 自動deploy / destroy (GitHub Actions main)
# GitHub OIDCでHannibalCICDRole-DevをAssumeRoleWithWebIdentity

# PR terraform plan (GitHub Actions pull_request)
# GitHub OIDCでHannibalPRPlanRole-DevをAssumeRoleWithWebIdentity
```

### **管理方針**
- **IAMユーザー**: 完全手動管理
- **基盤IAMロール・ポリシー**: `terraform/foundation` で扱い、厳密運用で変更する
- **ECS Permission Boundary**: `HannibalECSBoundary` は ECS Role 本体ではなく、deploy / destroy で作成されるアプリIAMに対する永続ガードレールとして `terraform/foundation` で扱う。ECS Task Execution Role、Secrets read policy、policy attachment は `terraform/environments/dev` で作成・破棄する
- **Foundation Boundary 変更**: `HannibalFoundationRole-Dev` ではなく、bootstrap / admin / break-glass 権限で厳密運用として実行する
- **Foundation Policy 分割**: `HannibalFoundationPolicy-Dev` は core IAM / OIDC / Permission Boundary 権限に限定し、state 権限は `HannibalFoundationStatePolicy-Dev`、managed service 権限は `HannibalFoundationServicesPolicy-Dev` に分ける
- **日常開発Role**: `HannibalDeveloperRole-Dev` はアプリ運用に使い、`terraform/foundation` の apply には使わない
- **Boundary命名規約**: Foundation Role が Hannibal 系 Role に設定できる Permission Boundary は `Hannibal*Boundary*` に限定する
- **Developer Role 最小権限化**: 既存 Role / Policy を直接縮小せず、candidate Role / Policy / Boundary で検証してから本体へ反映する
- **アプリケーションIAMロール・ポリシー**: `terraform/environments/dev` から作成・破棄される
- **段階的権限縮小**: CloudTrailログ分析とPRレビューで継続的に行う

## 🏗️ 設計原則

### 基盤とアプリケーションの分離
- **基盤IAMリソース**: 永続保持し、変更時は厳密運用で扱う
- **アプリケーションIAMリソース**: Terraform管理・一時的
- **foundation apply 権限**: 日常開発用 Role ではなく `HannibalFoundationRole-Dev` に分離する

`HannibalDeveloperRole-Dev` の権限範囲（#164 で確定）:
- **残す**: ECR push / pull、ECS exec / service / task 確認、CloudWatch Logs 確認、Secrets Manager read（`nestjs-hannibal-3-*` / `rds!*`）、dev Terraform plan（`-lock=false`）、S3 frontend / codedeploy-artifacts 操作
- **外した**: wildcard 権限全般、`nestjs-hannibal-3-*` IAM write（CICD Role に委譲）、`Hannibal*` IAM / OIDC / foundation state / CloudTrail / Athena / Budgets（Foundation Role に分離）
- **追加**: `HannibalDeveloperBoundary-Dev` による最大権限の上限設定

`HannibalDeveloperRole-Dev` への変更は candidate role（`HannibalDeveloperRole-Dev-candidate`）で事前検証済み（#164、PR #190〜#194）。

### 最小権限の原則
- **CloudTrail分析**: 実際の使用権限を特定する
- **Permission Boundary**: 最大権限の制限
- **Boundaryの管理分離**: 日常 apply 用 Role が自分の Boundary を書き換えられないようにする
- **Boundaryの命名制限**: `Hannibal*Boundary*` に一致する managed policy だけを Hannibal 系 Role の Boundary として使う
- **Boundaryの粒度**: `HannibalFoundationBoundary-Dev` は詳細な実権限ではなく、foundation が扱うサービス範囲の上限だけを短く定義する。詳細な許可は Foundation Role に attach する core/state/services の managed policy 側で管理する
- **Foundation Policy の文字数余裕**: AWS IAM managed policy の上限 6144 文字へ近づけない。Foundation Role の identity policy は `HannibalFoundationPolicy-Dev`（core IAM / OIDC / Permission Boundary）、`HannibalFoundationStatePolicy-Dev`（backend state / lock）、`HannibalFoundationServicesPolicy-Dev`（Athena / Glue Data Catalog / CloudTrail / GuardDuty / Budgets / cloudtrail-logs bucket policy）に責務で分割し、将来の権限追加は該当責務の policy に閉じる
- **段階的権限縮小**: 過去分析を起点に、現状確認と縮小を継続する

### 環境分離
- **開発環境**: HannibalDeveloperRole-Dev
- **foundation apply環境**: HannibalFoundationRole-Dev
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
        "Federated": "arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com"
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

### terraform/foundation apply の注意点

#### `aws_iam_policy` の `description` は ForceNew

Terraform の `aws_iam_policy` で `description` を変更すると、リソースが destroy → create（置き換え）になる。置き換えの際、Terraform はまず既存ポリシーを Role から detach しようとする。

Foundation Policy の `DetachRolePolicy` 文には次の条件が付いている:

```
Condition:
  ArnLike:
    iam:PermissionsBoundary: "arn:aws:iam::...:policy/Hannibal*Boundary*"
```

これは「detach 対象の Role がすでに `Hannibal*Boundary*` の Boundary を持っているときだけ許可」という意味。Boundary を持たない Role（例: 新しく Boundary を付ける対象）への detach は AccessDenied になる。

**結論**: `aws_iam_policy` の `description` は変更しない。policy 内容だけを変えれば in-place update（新バージョン作成）になり、detach が不要になる。

#### Boundary を持たない Role への最初の apply

Boundary がない Role に対して「Boundary を付与 + ポリシーを置き換え」を同一 apply で実行しようとすると上記で詰まる。安全な順序:

1. Boundary 付与のみを apply する（`-target=aws_iam_role.*`）
2. 次の apply でポリシー操作を実施する

または policy の description を変えず in-place update にとどめれば 1 回の apply で通る。

#### policy を分割・縮小する際は `depends_on` で apply 順序を制御する

既存 policy から権限を外す前に新しい policy を Role に attach する必要がある場合（policy 分割など）、apply 順序を明示しないと Role が一時的に権限を失う。

Terraform の依存グラフは参照関係から構築される。新しい attachment と既存 policy の更新の間に参照関係がなければ、Terraform は順序を自動解決できず、既存 policy の縮小が先に走る可能性がある。

対策: **縮小する側の policy リソース**に `depends_on` を置き、新しい attachment の完了後に更新されるよう強制する。

```hcl
resource "aws_iam_policy" "hannibal_foundation_policy" {
  # ...
  depends_on = [
    aws_iam_role_policy_attachment.hannibal_foundation_state_policy_attachment,
    aws_iam_role_policy_attachment.hannibal_foundation_services_policy_attachment,
  ]
}
```

これにより apply の順序が保証される。

```text
1. 新しい policy を作る
2. Role に attach する
3. 既存 policy を縮小する
```

attachment リソース側ではなく policy リソース側に置くのがポイント。attachment に `depends_on` を置いても既存 policy の縮小順序は制御できない。

#### apply 後は Foundation Role を assume して plan を実行する

Foundation Role の policy を変更した apply が成功しても、それは「apply が通った」という事実にすぎない。apply を実行した実行者と Foundation Role では権限が異なり、apply（リソース作成・更新）と plan（既存リソースの refresh）では必要な action も異なる。

apply 後は必ず Foundation Role を assume して `terraform/foundation plan` を実行し、`No changes` になることを確認する。

```bash
read AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN < <(
  aws sts assume-role \
    --role-arn arn:aws:iam::xxxxxxxxxxxx:role/HannibalFoundationRole-Dev \
    --role-session-name foundation-post-apply-check \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
    --output text
)

AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN" \
terraform -chdir=terraform/foundation plan -no-color -input=false
```

期待する結果: `No changes. Your infrastructure matches the configuration.`

AccessDenied が出た場合は、不足している action を該当責務の policy（core / state / services）に追加して再 apply する。

### candidate を使うかどうかの判断

変更の性質によって candidate Role を作るかどうかを判断する。

| 変更の種類 | candidate | 理由 |
|---|---|---|
| 権限の中身が変わる（wildcard → action 列挙、権限削除） | **使う** | 変更後の Role が動作するかを本体に反映する前に確認できる |
| 権限の中身は同じで構造を変える（policy 分割・統合） | **不要** | 合計権限が変わらない。`depends_on` と apply 後の実 Role 検証で代替できる |
| 権限を追加する | **不要** | リスクが低い。apply 後の実 Role 検証で十分 |

candidate を使わない場合でも、apply 後の Foundation Role assume + plan 実行は必須。

### Developer Role candidate 検証プロセス
1. bootstrap / admin / break-glass 権限で `terraform/foundation` を apply し、`HannibalDeveloperRole-Dev-candidate` / `HannibalDeveloperPolicy-Dev-candidate` / `HannibalDeveloperBoundary-Dev-candidate` を作成する
2. `hannibal` IAM User の `AssumeDevRole` が Role ARN を明示している場合、検証期間中だけ candidate Role ARN を追加する
3. candidate Role を assume し、ECS exec、CloudWatch Logs 確認、ECR push、Secrets 参照、`terraform/environments/dev` の lock あり plan を確認する
4. AccessDenied が出たら candidate policy を最小差分で修正し、再検証する
5. 検証完了後、後続 PR で本体 `HannibalDeveloperPolicy-Dev` / Developer Role Boundary に反映し、candidate リソースを削除する

### candidate 検証記録（#164）

**リソース作成**: PR #190（`HannibalDeveloperRole-Dev-candidate` / `HannibalDeveloperPolicy-Dev-candidate` / `HannibalDeveloperBoundary-Dev-candidate`）、apply 済み。

**deploy なし検証結果（2026-05-09 時点）**:

| テスト | 結果 | 備考 |
|---|---|---|
| `terraform/environments/dev plan`（lock あり） | AccessDenied | `dynamodb:PutItem` / `GetItem` 権限なし。#189 で DynamoDB 削除後に解消予定 |
| `terraform/environments/dev plan`（`-lock=false`） | OK | state 読み取り成功、72 to add |
| S3 frontend bucket put / delete | OK | `nestjs-hannibal-3-frontend` |
| ECR push / pull 系（IAM simulation） | all allowed | `ecr:GetAuthorizationToken` / `PutImage` / `InitiateLayerUpload` 等 |
| foundation state `s3:GetObject` | explicitDeny ✓ | policy の Deny ステートメントが機能している |
| IAM 危険操作（CreateRole / DeleteRole / Attach / Put 等） | all implicitDeny ✓ | |

**dev deploy あり検証結果（2026-05-09）**:

| テスト | 結果 | 備考 |
|---|---|---|
| ECS exec（IAM simulation） | allowed ✓ | ローカルに Session Manager Plugin なし。IAM 権限は確認済み |
| CloudWatch Logs `get-log-events` | OK ✓ | `/ecs/nestjs-hannibal-3-api-task` を実読み取り |
| Secrets Manager `GetSecretValue`（RDS managed secret） | OK ✓ | `rds!db-*` prefix のシークレットを取得確認 |
| `terraform/environments/dev plan -lock=false` | OK ✓ | deploy 後の state 読み取り成功 |
| foundation state `s3:GetObject` | explicitDeny ✓ | |
| `HannibalFoundationRole-Dev` assume（特権昇格テスト） | AccessDenied ✓ | |

**既知の制限**:
`terraform/environments/dev` の backend は `use_lockfile = true` と `dynamodb_table` を並用中（#189 待ち移行期間）。candidate policy は DynamoDB 権限を持たないため、`-lock=false` での plan が必要。#189 で DynamoDB が削除されれば S3 lockfile 単独になり、lock あり plan が通る。

**完了**: 全検証通過。`HannibalDeveloperPolicy-Dev` を action 列挙に更新、`HannibalDeveloperBoundary-Dev` を新設・付与、candidate リソースを削除（#164 最終 PR にて）。

### 定期メンテナンス
- **月次権限レビュー**: 使用されていない権限の特定
- **四半期最適化**: Permission Boundaryの見直し
- **年次監査**: 全体的なIAM構成の見直し
