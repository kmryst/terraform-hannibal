# Terraform Runbook

この Runbook は Terraform 固有の運用手順をまとめる正本です。
CloudWatch Alarm、ECS、CodeDeploy の障害対応は [runbook.md](./runbook.md) を参照します。
Terraform apply 失敗、誤変更、state 復元の戻し方は [rollback-plan.md](./rollback-plan.md) を参照します。

## 前提

- AWS region は `ap-northeast-1` を基本とする。
- Terraform state は S3 bucket `nestjs-hannibal-3-terraform-state` に保存する。
- state lock は S3 lockfile（`use_lockfile = true`）を使用する。DynamoDB lock table `terraform-state-lock` は全 root module で不使用（テーブル削除は #189）。
- `terraform apply` / `terraform destroy` / `terraform state rm` は厳密運用の対象として扱い、事前確認なしに実行しない。
- コマンド出力に secret や credential が含まれる可能性がある場合は、値を貼り付けずに状態だけ共有する。

## 操作対象と Role

| 対象 | ディレクトリ | State key | Lockfile key | 主な Role |
|---|---|---|---|---|
| foundation | `terraform/foundation` | `foundation/terraform.tfstate` | `foundation/terraform.tfstate.tflock` | `HannibalFoundationRole-Dev` |
| network | `terraform/network` | `network/terraform.tfstate` | `network/terraform.tfstate.tflock` | local plan: `HannibalDeveloperRole-Dev`, deploy/destroy: `HannibalCICDRole-Dev` |
| database | `terraform/database` | `database/terraform.tfstate` | `database/terraform.tfstate.tflock` | local plan: `HannibalDeveloperRole-Dev`, deploy/destroy: `HannibalCICDRole-Dev` |
| service | `terraform/service` | `service/terraform.tfstate` | `service/terraform.tfstate.tflock` | local plan: `HannibalDeveloperRole-Dev`, deploy/destroy: `HannibalCICDRole-Dev` |
| cdn | `terraform/cdn` | `cdn/terraform.tfstate` | `cdn/terraform.tfstate.tflock` | local plan: `HannibalDeveloperRole-Dev`, deploy/destroy: `HannibalCICDRole-Dev` |

> **注意**: 以下のコマンド例は旧構成（`terraform/environments/dev`）に基づいています。state 分割後は、対象の root module ディレクトリに読み替えてください。runbook の全面改訂は #398 で対応します。

Role の正本は [iam-management.md](./iam-management.md) です。
`HannibalDeveloperRole-Dev` は日常開発・アプリ運用と dev plan 用であり、`terraform/foundation` の apply には使いません。
PR の Terraform plan は `HannibalPRPlanRole-Dev` を使い、`-lock=false` で実行します。

## 共通確認

Terraform 操作前に、対象 branch、AWS principal、並行実行中の workflow を確認します。

```bash
git status --short --branch
aws sts get-caller-identity

gh run list --workflow deploy.yml --limit 5
gh run list --workflow destroy.yml --limit 5
gh run list --workflow pr-check.yml --limit 5
```

`aws sts get-caller-identity` の結果は account / arn の確認に使い、credential 値は出力しません。
deploy / destroy / PR plan が実行中の場合は、state lock を触る前に完了を待ちます。

## init

backend 設定を初期化します。backend 設定を変更した後、または既存 checkout で backend を読み直す場合は `-reconfigure` を付けます。

```bash
terraform -chdir=terraform/foundation init -input=false
terraform -chdir=terraform/foundation init -reconfigure -input=false

terraform -chdir=terraform/environments/dev init -input=false
terraform -chdir=terraform/environments/dev init -reconfigure -input=false
```

`terraform/environments/dev` は `client/dist` を Terraform の `fileset` で参照します。
ローカルで plan / apply する前に frontend build を済ませます。

```bash
npm --prefix client ci
npm --prefix client run build
```

## plan

### foundation plan

`terraform/foundation` は `alert_email` を `terraform.tfvars` で与えるのが基本です。

```bash
terraform -chdir=terraform/foundation plan \
  -refresh=true \
  -lock=true \
  -input=false \
  -out=tfplan
```

### dev plan

local plan は `HannibalDeveloperRole-Dev` を assume して実行します。
必須変数は GitHub Variables と同じ値を使います。値は secret ではありませんが、ARN や hosted zone ID を共有する必要がない場合は貼り付けません。

```bash
terraform -chdir=terraform/environments/dev plan \
  -refresh=true \
  -lock=true \
  -input=false \
  -detailed-exitcode \
  -out=tfplan \
  -var="client_url_for_cors=https://hamilcar-hannibal.click" \
  -var="environment=dev" \
  -var="deployment_type=canary" \
  -var="enable_cloudfront=true" \
  -var="ecr_repository_url=${ECR_REPOSITORY_URL}" \
  -var="alb_certificate_arn=${ALB_CERTIFICATE_ARN}" \
  -var="acm_certificate_arn_us_east_1=${ACM_CERTIFICATE_ARN_US_EAST_1}" \
  -var="hosted_zone_id=${HOSTED_ZONE_ID}"
```

`-detailed-exitcode` の意味:

| Exit code | 意味 | 扱い |
|---:|---|---|
| 0 | plan 成功、差分なし | 正常 |
| 1 | エラー | 調査対象 |
| 2 | plan 成功、差分あり | dev が destroy 済みなら全作成差分は正常系 |

### PR plan

PR plan は GitHub Actions の `pr-check.yml` で `HannibalPRPlanRole-Dev` を使って実行します。
この Role は read-only のため、S3 lockfile の write/delete 権限を持ちません。
そのため `-lock=false` が前提です。

```bash
terraform -chdir=terraform/environments/dev plan \
  -refresh=true \
  -lock=false \
  -input=false \
  -no-color \
  -detailed-exitcode \
  -out=tfplan \
  -var="client_url_for_cors=https://hamilcar-hannibal.click" \
  -var="environment=dev" \
  -var="deployment_type=canary" \
  -var="enable_cloudfront=true" \
  -var="ecr_repository_url=${ECR_REPOSITORY_URL}" \
  -var="alb_certificate_arn=${ALB_CERTIFICATE_ARN}" \
  -var="acm_certificate_arn_us_east_1=${ACM_CERTIFICATE_ARN_US_EAST_1}" \
  -var="hosted_zone_id=${HOSTED_ZONE_ID}"
```

### target 指定

`-target` は通常運用の近道ではなく、復旧や切り分けのための限定手段として扱います。
target plan 後も、最終判断は target なしの full plan で確認します。

```bash
terraform -chdir=terraform/environments/dev plan \
  -target=module.rds \
  -refresh=true \
  -lock=true \
  -input=false \
  -out=tfplan-rds \
  -var="client_url_for_cors=https://hamilcar-hannibal.click" \
  -var="environment=dev" \
  -var="deployment_type=canary" \
  -var="enable_cloudfront=true" \
  -var="ecr_repository_url=${ECR_REPOSITORY_URL}" \
  -var="alb_certificate_arn=${ALB_CERTIFICATE_ARN}" \
  -var="acm_certificate_arn_us_east_1=${ACM_CERTIFICATE_ARN_US_EAST_1}" \
  -var="hosted_zone_id=${HOSTED_ZONE_ID}"
```

## apply

### foundation apply

`terraform/foundation` の apply は `HannibalFoundationRole-Dev` で実行します。
IAM / OIDC / Permission Boundary / CloudTrail / Athena / Budgets に影響するため厳密運用として扱います。

```bash
terraform -chdir=terraform/foundation plan \
  -refresh=true \
  -lock=true \
  -input=false \
  -out=tfplan

terraform -chdir=terraform/foundation apply tfplan
```

### dev application apply

dev application の通常 apply は、`deploy.yml` を `main` から手動実行するルートを正とします。
workflow 内では plan を作成してから `terraform apply -auto-approve tfplan` を実行します。

```bash
gh workflow run deploy.yml \
  --ref main \
  -f deployment_mode=provisioning
```

`deployment_mode` は `provisioning` / `bluegreen` / `canary` のいずれかです。
`provisioning` は初回構築用で、Terraform の `deployment_type` としては `canary` を使います。

local の `terraform apply` は例外運用です。
実行する場合は、Issue / PR / rollback 方針 / 人間確認を揃え、`-auto-approve` を使わず保存済み plan を apply します。

```bash
terraform -chdir=terraform/environments/dev apply tfplan
```

## force-unlock

state lock error が出た場合、まず別の Terraform 実行が残っていないことを確認します。
実行中の deploy / destroy / PR plan がある場合は force-unlock しません。

```bash
gh run list --workflow deploy.yml --limit 5
gh run list --workflow destroy.yml --limit 5
gh run list --workflow pr-check.yml --limit 5
```

S3 lockfile の残留確認:

```bash
STATE_BUCKET="nestjs-hannibal-3-terraform-state"
STATE_KEY="environments/dev/terraform.tfstate"
LOCK_KEY="${STATE_KEY}.tflock"

aws s3api head-object \
  --bucket "$STATE_BUCKET" \
  --key "$LOCK_KEY"
```

Terraform のエラー出力に表示された `Lock ID` を使って解除します。

```bash
terraform -chdir=terraform/environments/dev force-unlock <LOCK_ID>
```

foundation の lock を解除する場合:

```bash
terraform -chdir=terraform/foundation force-unlock <LOCK_ID>
```

force-unlock 後は必ず plan を再実行し、state と実リソースの整合を確認します。
`.tflock` の手動削除は最終手段です。実行する場合は、対象 state、残留理由、並行実行がないことを確認し、厳密運用として扱います。

**レガシー DynamoDB stale lock の確認**

全 root module が S3 lockfile に移行済みのため、通常は DynamoDB に lock エントリが作られることはありません。
万が一、過去の stale エントリが残っている場合は以下で確認・削除します。DynamoDB テーブル本体の削除は #189 で扱います。

```bash
aws dynamodb scan --table-name terraform-state-lock
```

## S3 lockfile 実動作確認

S3 lockfile が作成・削除されることだけを確認する場合は、lock あり plan を実行します。
`apply` は不要です。
dev 環境が destroy 済みの場合、exit code `2` と全作成差分は正常系として扱います。

実行前に lockfile が残っていないことを確認します。

```bash
STATE_BUCKET="nestjs-hannibal-3-terraform-state"
STATE_KEY="environments/dev/terraform.tfstate"
LOCK_KEY="${STATE_KEY}.tflock"

aws s3api head-object \
  --bucket "$STATE_BUCKET" \
  --key "$LOCK_KEY"
```

`head-object` が `404` / `Not Found` を返す場合は、実行前 lockfile なしです。

別ターミナルで plan 中の `.tflock` を観測します。

```bash
STATE_BUCKET="nestjs-hannibal-3-terraform-state"
STATE_KEY="environments/dev/terraform.tfstate"
LOCK_KEY="${STATE_KEY}.tflock"

while true; do
  if aws s3api head-object --bucket "$STATE_BUCKET" --key "$LOCK_KEY" >/dev/null 2>&1; then
    echo "observed: present"
    break
  fi
  sleep 0.5
done
```

元のターミナルで lock ありの plan を実行します。

```bash
terraform -chdir=terraform/environments/dev plan \
  -lock=true \
  -lock-timeout=20s \
  -refresh=false \
  -input=false \
  -detailed-exitcode \
  -var="client_url_for_cors=https://hamilcar-hannibal.click" \
  -var="environment=dev" \
  -var="deployment_type=canary" \
  -var="enable_cloudfront=true" \
  -var="ecr_repository_url=${ECR_REPOSITORY_URL}" \
  -var="alb_certificate_arn=${ALB_CERTIFICATE_ARN}" \
  -var="acm_certificate_arn_us_east_1=${ACM_CERTIFICATE_ARN_US_EAST_1}" \
  -var="hosted_zone_id=${HOSTED_ZONE_ID}"
```

plan 終了後に lockfile が削除されていることを確認します。

```bash
aws s3api head-object \
  --bucket "$STATE_BUCKET" \
  --key "$LOCK_KEY"
```

期待結果:

- plan 実行中に `.tflock` が一時的に存在する。
- plan 終了後、`.tflock` は存在しない。
- exit code `0` は差分なし、`2` は差分あり、`1` はエラー。

## import

既存 AWS リソースが存在するが Terraform state にない場合は、import で state に取り込みます。
import は remote resource を作成・変更しませんが、state を変更するため実行前に対象 resource address と ID を確認します。

1. 既存リソースを AWS CLI / Console で特定する。
2. Terraform の resource address を確認する。
3. import を実行する。
4. target なしの full plan で差分を確認する。

```bash
terraform -chdir=terraform/environments/dev state list

terraform -chdir=terraform/environments/dev import \
  '<resource-address>' \
  '<aws-resource-id>'

terraform -chdir=terraform/environments/dev plan \
  -refresh=true \
  -lock=true \
  -input=false \
  -var="client_url_for_cors=https://hamilcar-hannibal.click" \
  -var="environment=dev" \
  -var="deployment_type=canary" \
  -var="enable_cloudfront=true" \
  -var="ecr_repository_url=${ECR_REPOSITORY_URL}" \
  -var="alb_certificate_arn=${ALB_CERTIFICATE_ARN}" \
  -var="acm_certificate_arn_us_east_1=${ACM_CERTIFICATE_ARN_US_EAST_1}" \
  -var="hosted_zone_id=${HOSTED_ZONE_ID}"
```

resource address は module 配下の実アドレスを使います。
たとえば module 内リソースなら `module.<module_name>.<resource_type>.<resource_name>` の形式になります。
import 後に大きな置き換え差分が出る場合は、設定値の不一致を先に直し、apply しません。

## drift 確認

drift 確認は「Terraform state と実 AWS リソースがずれていないか」を見るための確認です。
dev 環境は通常 destroy 済みのため、通常 plan で全作成差分が出ることがあります。
稼働中の dev に対する drift 確認では `-refresh-only` を使います。

```bash
terraform -chdir=terraform/environments/dev plan \
  -refresh-only \
  -lock=true \
  -input=false \
  -detailed-exitcode \
  -var="client_url_for_cors=https://hamilcar-hannibal.click" \
  -var="environment=dev" \
  -var="deployment_type=canary" \
  -var="enable_cloudfront=true" \
  -var="ecr_repository_url=${ECR_REPOSITORY_URL}" \
  -var="alb_certificate_arn=${ALB_CERTIFICATE_ARN}" \
  -var="acm_certificate_arn_us_east_1=${ACM_CERTIFICATE_ARN_US_EAST_1}" \
  -var="hosted_zone_id=${HOSTED_ZONE_ID}"
```

foundation の drift 確認:

```bash
terraform -chdir=terraform/foundation plan \
  -refresh-only \
  -lock=true \
  -input=false \
  -detailed-exitcode
```

drift が見つかった場合:

- 手動変更の有無を CloudTrail / Issue / PR / GitHub Actions run で確認する。
- Terraform 設定へ取り込むか、実リソースを戻すかを Issue で判断する。
- state だけを直接編集して解消しない。

## state 確認

state を読むだけの確認は次を使います。

```bash
terraform -chdir=terraform/environments/dev state list
terraform -chdir=terraform/environments/dev state show '<resource-address>'
```

`terraform state rm` は state から管理対象を外す破壊的な操作です。
実行する場合は、対象、理由、戻し方を明記し、事前確認を取ります。
