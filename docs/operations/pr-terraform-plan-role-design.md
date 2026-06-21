# PR Terraform Plan Role Design

Issue #121 の設計メモです。Terraform 実装は #127、workflow 実装は #122 で扱います。

IAM Role 一覧の正本は [iam-management.md](./iam-management.md) です。この文書は Role カタログではなく、`HannibalPRPlanRole-Dev` を新設するための詳細設計補足として扱います。

## 結論

PR の `terraform plan` では、既存の `HannibalCICDRole-Dev` を使わず、dev 環境専用の plan-only Role を新設します。

理由:

- `HannibalCICDRole-Dev` は main ブランチの deploy / destroy 用で、PR から使うには権限が強すぎる
- PR plan は apply / destroy ではなく、destroy 済み dev 環境を再構築できそうかを見るレビュー補助である
- PR workflow は外部入力を含むため、AssumeRole できる GitHub OIDC subject を deploy / destroy と分ける必要がある

想定Role名:

- `HannibalPRPlanRole-Dev`

## 前提

- GitHub OIDC Provider は既存の `token.actions.githubusercontent.com` を使う
- AWS account は dev 用の `<account-id>`
- Terraform root module は `terraform/environments/dev`
- backend は S3 bucket `nestjs-hannibal-3-terraform-state`、key `environments/dev/terraform.tfstate`
- backend は `use_lockfile = true` で S3 lockfile を使う。PR plan は `-lock=false` のため `.tflock` の作成・削除はしない
- dev 環境は通常 destroy 済みで、PR plan の全作成差分は正常系として扱う
- PR plan workflow は `pull_request` で実行し、`pull_request_target` では PR head のコードを実行しない
- fork PR では AWS Role を assume せず、plan job を skip する
- plan Role 自体の Terraform 実装は `terraform/foundation` 側で扱うため、初回作成は #127 で人間確認のうえ実行する

## Trust Policy

PR plan Role は GitHub Actions OIDC からの `sts:AssumeRoleWithWebIdentity` だけを許可します。

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Principal": {
        "Federated": "arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:kmryst/terraform-hannibal:pull_request"
        }
      }
    }
  ]
}
```

補足:

- GitHub の pull request event 用 OIDC subject は `repo:ORG/REPO:pull_request`
- AWS 向け GitHub OIDC では `aud=sts.amazonaws.com` を使う
- `repo:kmryst/terraform-hannibal:*` のような wildcard は使わない
- GitHub Environment を plan job に付ける場合、OIDC subject が `environment:<name>` へ変わるため、この設計では使わない
- fork PR 除外は IAM trust policy だけでは表現しきれないため、workflow 側の `if` でも必ず制御する

workflow 側の前提条件:

```yaml
permissions:
  id-token: write
  contents: read

jobs:
  terraform-plan:
    if: github.event.pull_request.head.repo.full_name == github.repository
```

## 権限方針

このRoleには apply / destroy / write 系権限を付けません。Terraform plan が必要とする read / list / describe / get 系権限だけを許可します。

明示的に含めない権限:

- `iam:PassRole`
- `terraform apply` や `terraform destroy` に必要な create / update / delete / put / modify / attach / detach 系権限
- S3 backend state / lockfile への `s3:PutObject` / `s3:DeleteObject`
- DynamoDB lock table への `dynamodb:PutItem` / `dynamodb:DeleteItem`（レガシー。全 root module は S3 lockfile に移行済み）
- Secrets Manager の `secretsmanager:GetSecretValue`
- ECR image push / upload 系権限

ただし、Terraform state そのものは機密情報を含み得ます。plan Role は state を読むため、単なる「無害な読み取り権限」ではなく、信頼できる repository 内 PR だけで使う前提にします。

## Permission Boundary

#139 の検討結果として、`HannibalPRPlanRole-Dev` には専用の `HannibalPRPlanBoundary-Dev` を付与します。

理由:

- identity policy は read-only に限定しているが、将来の policy 変更ミスで write 系権限が混入する可能性を Boundary で抑える
- PR workflow は外部入力を含み得る経路なので、Trust Policy / workflow の fork skip / identity policy / Permission Boundary の複数層で守る
- DevOps ポートフォリオとして、PR から AWS を読む Role に defense-in-depth を設計していることを示せる

`HannibalCICDBoundary` は流用しません。これは main の deploy / destroy 用 Role の上限であり、write 系操作を前提にしています。plan-only Role に流用すると、PR plan Role の最大権限としては広すぎます。

`HannibalPRPlanBoundary-Dev` は、PR plan に必要な read / list / describe / get 系のみを最大権限として許可します。次の権限は Boundary に含めません。

- `iam:PassRole`
- `s3:PutObject` / `s3:DeleteObject`
- `dynamodb:PutItem` / `dynamodb:DeleteItem`
- `secretsmanager:GetSecretValue`
- create / update / delete / put / modify / attach / detach 系の write 権限

## Backend Read Permissions

`terraform init` と `terraform plan -lock=false` で backend state を読むため、S3 state には read のみを許可します。
`use_lockfile = true` は backend 側で有効ですが、PR plan は `-lock=false` のため `.tflock` を作成・削除しません。

```json
[
  {
    "Effect": "Allow",
    "Action": "s3:ListBucket",
    "Resource": "arn:aws:s3:::nestjs-hannibal-3-terraform-state",
    "Condition": {
      "StringLike": {
        "s3:prefix": [
          "environments/dev/",
          "environments/dev/terraform.tfstate"
        ]
      }
    }
  },
  {
    "Effect": "Allow",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::nestjs-hannibal-3-terraform-state/environments/dev/terraform.tfstate"
  }
]
```

方針:

- PR plan は `-lock=false` で実行する
- S3 lockfile 用の `s3:PutObject` / `s3:DeleteObject` は PR plan Role に付与しない
- DynamoDB lock table への write 権限は付けない（全 root module が S3 lockfile に移行済みのため不要）

## Terraform Read Permissions

初期実装では、Terraform provider の refresh と data source 参照に必要な read 権限をサービス単位で整理し、#127 で実際の IAM policy に落とします。

必須寄り:

- `sts:GetCallerIdentity`
- `ec2:Describe*`
- `elasticloadbalancing:Describe*`
- `ecs:Describe*`, `ecs:List*`
- `ecr:DescribeRepositories`, `ecr:GetLifecyclePolicy`, `ecr:ListTagsForResource`
- `rds:Describe*`, `rds:ListTagsForResource`
- `logs:Describe*`, `logs:ListTagsForResource`
- `cloudwatch:DescribeAlarms`, `cloudwatch:GetDashboard`, `cloudwatch:ListTagsForResource`
- `sns:GetTopicAttributes`, `sns:GetSubscriptionAttributes`, `sns:ListSubscriptionsByTopic`, `sns:ListTagsForResource`
- `codedeploy:Get*`, `codedeploy:List*`
- `iam:GetRole`, `iam:ListRolePolicies`, `iam:GetRolePolicy`, `iam:ListAttachedRolePolicies`, `iam:GetPolicy`, `iam:GetPolicyVersion`, `iam:ListPolicyVersions`, `iam:ListInstanceProfilesForRole`

既存 data source / 永続リソース参照:

- **S3: `s3:Get*`, `s3:List*`**（`Resource: "*"`）
- `route53:GetHostedZone`, `route53:ListHostedZones`, `route53:ListHostedZonesByName`, `route53:ListResourceRecordSets`, `route53:ListTagsForResource`
- `cloudfront:GetOriginAccessControl`, `cloudfront:ListOriginAccessControls`, `cloudfront:GetDistribution`, `cloudfront:GetDistributionConfig`, `cloudfront:ListTagsForResource`
- `secretsmanager:DescribeSecret`, `secretsmanager:GetResourcePolicy`, `secretsmanager:ListSecretVersionIds`

注意:

- 多くの AWS read API は resource-level restriction が効かないため、`Resource: "*"` が必要になる
- S3 は `s3:Get*` / `s3:List*` のワイルドカードを採用している。理由: Terraform provider の refresh がデプロイ済み環境に対して呼ぶ S3 API（`GetBucketCORS`, `GetBucketWebsite`, `GetAccelerateConfiguration`, `GetObjectTagging` 等）はプロバイダーのバージョンによって増減し、個別列挙では継続的な whack-a-mole になる。このロールは plan 専用（read-only）であり、`s3:Put*` / `s3:Delete*` は含まないため、read ワイルドカードのリスクは write 権限と質が異なる。
- S3 state ファイルの `s3:GetObject` は別ステートメントで ARN を限定している（最小権限の原則を適用できる範囲で適用）
- S3 lockfile は plan lock を取る場合に `s3:GetObject` / `s3:PutObject` / `s3:DeleteObject` が必要になるが、このRoleは `-lock=false` のため write/delete を持たせない

## Workflow Contract

#122 の workflow は、このRoleを次の前提で使います。

- `pull_request` で起動する
- fork PR では plan job を skip する
- `pull_request_target` では PR head の Terraform を実行しない
- `aws-actions/configure-aws-credentials` で `HannibalPRPlanRole-Dev` を assume する
- `terraform/environments/dev` で backend ありの `terraform init` を実行する
- `terraform plan -refresh=true -lock=false -input=false -no-color -detailed-exitcode` を実行する
- `client/dist` を参照する `aws_s3_object` があるため、plan 前に frontend build を行う
- binary plan file は artifact 保存しない。保存する場合は機密値リスクを明記し、短期 retention にする

## 実装順序

1. #121: この設計を確定する
2. #127: `HannibalPRPlanRole-Dev` と policy を Terraform で実装する
3. #122: PR plan workflow から plan Role を assume して `terraform plan` を実行する
4. #125 / #124: Job Summary と危険シグナル抽出を追加する
5. #128: required status check にするかを判断する
6. #139: `HannibalPRPlanRole-Dev` 専用 Permission Boundary を追加する

## ロールバック方針

#121 は設計文書だけなので、ロールバックは文書差分の revert で足ります。

#127 の Role 実装後に問題が出た場合:

- plan用Role自身で作成・復旧しようとせず、既存の管理者権限または既存の strict 運用で foundation 側を戻す
- #122 の workflow から plan job を無効化する
- `HannibalPRPlanRole-Dev` の policy attachment を外す
- 必要なら `HannibalPRPlanRole-Dev` と inline / managed policy を削除する
- 既存の `HannibalCICDRole-Dev` には触れない
- state backend bucket / DynamoDB table / deploy / destroy workflow には触れない

## 参考

- [GitHub Docs: Configuring OpenID Connect in Amazon Web Services](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws)
- [GitHub Docs: OpenID Connect reference](https://docs.github.com/en/actions/reference/security/oidc)
- [Terraform Docs: `terraform plan`](https://developer.hashicorp.com/terraform/cli/commands/plan)
- [Terraform Docs: S3 backend permissions](https://developer.hashicorp.com/terraform/language/backend/s3)
