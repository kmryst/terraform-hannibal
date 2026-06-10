# Quality Gates

`terraform-hannibal` の PR で実行する品質ゲートと、各ツールの役割をまとめます。

## 目的

- Terraform / Dockerfile / Git 履歴を PR 時に自動確認する
- backend/frontend の build・test を deploy workflow ではなく PR gate に集約する
- Terraform 公式チェックだけでは見つけにくい provider 固有のミス、IaC セキュリティ設定、secret 混入を早期に検出する
- DevOps ポートフォリオとして、単に CI を並べるのではなく、目的別に品質ゲートを設計していることを示す

## PR チェック

| Job | ツール | 役割 | 2026-05-27 時点の扱い |
|---|---|---|---|
| `PR Policy Check` | `gh` / `jq` / shell | Issue link、必須ラベル、厳密運用時の rollback 欄を確認 | required status check 対象 |
| `Commitlint` | `commitlint` | PR title と PR 内コミットメッセージを Conventional Commits 形式で確認 | required status check 対象 |
| `Backend Lint & Build` | ESLint / Nest build | backend の lint と build を確認 | required status check 対象 |
| `Backend Test` | Jest | backend unit test を確認 | PR で自動実行 |
| `Frontend Build` | TypeScript / Vite build | frontend の型チェックと build を確認 | required status check 対象 |
| `Frontend Test` | Vitest | frontend unit test を確認 | PR で自動実行 |
| `Docker Build` | Docker | backend image build と non-root user を確認 | PR で自動実行 |
| `Terraform Format & Validate` | `terraform fmt` / `terraform validate` | HCL の整形と Terraform 構成の基本整合性を確認 | required status check 対象 |
| `TFLint` | `tflint` | Terraform / AWS provider 向けの lint。非推奨設定、未使用宣言、provider 固有のミスを検出 | required status check 対象。検出時は fail |
| `Trivy Config Scan` | `trivy config` | Terraform / Dockerfile などの IaC・設定ミスを検出 | PR で自動実行。review signal として扱い、検出しても fail しない |
| `Gitleaks Secret Scan` | `gitleaks` | Git 履歴に混入した API key / token / password などの secret を検出 | required status check 対象。検出時は fail |

## 定期 Security Scan

`security-scan.yml` は `workflow_dispatch` と週次 `schedule` で実行し、CodeQL と Trivy の結果を GitHub Security に残します。
PR ごとの早期検知は `pr-check.yml` に寄せ、Docker build や CodeQL 解析を含む重めの scan は定期監査として分けます。

| 観点 | `pr-check.yml` | `security-scan.yml` |
|---|---|---|
| 主目的 | PR の merge 前品質ゲート | 定期/手動のセキュリティ監査 |
| 実行タイミング | `pull_request` to `main` | 毎週月曜 00:15 UTC（09:15 JST）と手動実行 |
| セキュリティ範囲 | Secret 混入、IaC/Dockerfile 設定ミス、Terraform lint | 依存関係脆弱性、コンテナ脆弱性、CodeQL SAST |
| マージ可否への影響 | required status check を含み、PR を止める | 原則として PR merge gate にはしない |
| 結果の使い方 | PR 上の修正判断と Job Summary | GitHub Security / Code scanning alerts の定期確認 |

schedule は `15 0 * * 1` とし、毎時0分付近の GitHub Actions 混雑を避けるため15分にずらします。
GitHub Actions の schedule は UTC を基準にし、毎時0分付近では遅延や queued job の drop が起こる可能性があるためです（[GitHub Docs](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule)）。

`workflow_dispatch` による手動実行の連打を防ぐため、`concurrency: group: security-scan, cancel-in-progress: true` を設定しています。新しい実行が起動すると実行中の古いジョブをキャンセルし、常に最新コードのスキャン結果を得られるようにします。

### 2026-06-03 Node 24 / CodeQL v4 warning 対応

GitHub Actions の Node 20 runtime deprecation と CodeQL Action v3 deprecation warning に対応するため、JS action runtime が Node 24 になる action version へ更新しました。

参考:

- [Deprecation of Node 20 on GitHub Actions runners](https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/)
- [Upcoming deprecation of CodeQL Action v3](https://github.blog/changelog/2025-10-28-upcoming-deprecation-of-codeql-action-v3/)

更新した action:

| Action | 旧 | 新 | 主な対象 workflow |
|---|---|---|---|
| `github/codeql-action/*` | `v3` | `v4` | `security-scan.yml` |
| `actions/checkout` | `v4` | `v5` | 全 workflow |
| `actions/setup-node` | `v4` | `v5` | `pr-check.yml`, `deploy.yml` |
| `actions/upload-artifact` | `v4` | `v6` | `pr-check.yml` |
| `actions/github-script` | `v7` | `v8` | `issue-template-check.yml` |
| `docker/setup-buildx-action` | `v3` | `v4` | `security-scan.yml` |
| `docker/build-push-action` | `v5` | `v7` | `security-scan.yml` |
| `aws-actions/configure-aws-credentials` | `v4` | `v6` | `pr-check.yml`, `deploy.yml`, `destroy.yml` |
| `hashicorp/setup-terraform` | `v3` | `v4` | `pr-check.yml`, `deploy.yml`, `destroy.yml` |

据え置いた action:

| Action | 理由 |
|---|---|
| `aquasecurity/trivy-action@v0.36.0` | composite action であり、GitHub-hosted JavaScript action の Node 20 runtime warning 対象ではない。 |
| `aws-actions/amazon-ecr-login@v2` | 現行 major tag の action metadata が Node 24 runtime を使う。 |
| `terraform-linters/setup-tflint@v6` | 現行 major tag の action metadata が Node 24 runtime を使う。 |
| `micnncim/action-label-syncer@v1` | Docker action であり、GitHub-hosted JavaScript action の Node runtime warning 対象ではない。 |

`NODE_VERSION: "20"` や `node-version: '20'` は、workflow 上で実行する backend/frontend build・test の Node.js version です。
これは GitHub Actions の JavaScript action runtime warning とは別の互換性判断なので、本対応では変更しません。
アプリ実行・CI テスト用 Node.js を 24 へ上げる場合は、backend/frontend の依存関係とテスト安定性を確認する別 Issue として扱います。

残る warning がある場合は、annotation が指している action の `action.yml` / `action.yaml` の `runs.using` を確認します。
Node 20 runtime を使う JS action が残っていれば version 更新または別 action への置換を検討します。
Docker action / composite action / `actions/setup-node` でインストールしている Node.js 20 自体は、この warning とは別の扱いです。

### action バージョン管理方針

action の参照は owner の trust boundary で 2 tier に分けて固定します（[ADR 0017](../adr/0017-pin-github-actions-by-owner-tier.md)）。

| Tier | 対象 | 固定形式 | Dependabot alerts |
|---|---|---|---|
| A | GitHub-owned（`actions/*`, `github/codeql-action/*`） | `@vX.Y.Z` semver patch tag | 維持 |
| B | non-GitHub-owned（上記以外の全外部 action） | `@<full-length-sha> # vX.Y.Z` SHA pin | 無効（version updates で補完） |

**version / SHA の決定方法**: `@vX` floating major tag が現時点で指す commit SHA を `git ls-remote` で取得し、その commit に対応する semver patch tag を逆引きして固定します。pin 操作とバージョンアップを分離するため、「最新 patch を選ぶ」のではなく「floating tag が今この瞬間に指している version に固定する」方針を取ります。

Dependabot の週次 version updates は継続し、SHA と `# vX.Y.Z` コメントを追従更新します。Dependabot が生成した PR は CI（`pr-check.yml`）を通過後にマージします。major version 更新はリリースノートを確認してからマージします。

Dependency graph / Dependabot alerts (vulnerability alerts) / Dependabot security updates は有効化済みです（2026-06-10）。現在 pin している action の Tier 分類、SHA とコメントの対応確認、advisory 確認結果、Tier B の Dependabot version update PR レビュー手順は [action-pin-review.md](./action-pin-review.md) に記録します。

## deploy workflow との役割分担

`deploy.yml` は `workflow_dispatch` による `main` からの手動デプロイに限定する。backend/frontend の build・test は PR gate（`pr-check.yml`）に集約し、deploy workflow では再実行しない。

これにより、merge 前の品質確認は PR に寄せ、merge 後の deploy は Terraform apply、frontend build、S3 sync、ECR push、CodeDeploy に集中させる。

## ツールの位置づけ

| ツール | 管理元 | Terraform 公式か | このプロジェクトでの位置づけ |
|---|---|---|---|
| `terraform fmt` | HashiCorp / Terraform CLI | 公式 | HCL の標準フォーマット確認 |
| `terraform validate` | HashiCorp / Terraform CLI | 公式 | Terraform 構成の構文・参照整合性確認 |
| `tflint` | `terraform-linters` OSS | 非公式 | Terraform の実務 lint。AWS ruleset を利用 |
| `trivy config` | Aqua Security / Trivy | 非公式 | Terraform / Dockerfile などの IaC security scan |
| `gitleaks` | Gitleaks OSS | 非公式 | Git 履歴・ファイル内の secret scan |
| `tfsec` | Aqua Security | 非公式 | 新規採用しない。IaC security は Trivy Config に寄せる |

`terraform fmt` / `terraform validate` は「Terraform として読めるか」を確認します。
`tflint` / `trivy config` / `gitleaks` は、公式 CLI の外側で「実務上危ない設定がないか」を補完します。

## tfsec を新規採用しない理由

`tfsec` は Terraform 専用の IaC security scanner です。
ただし現在は同じ Aqua Security の `Trivy` が Terraform を含む複数種類の設定ファイルを横断的に扱えるため、このプロジェクトでは新規の品質ゲートを `trivy config` に寄せます。

これにより、Terraform だけでなく Dockerfile なども同じスキャン系統で確認できます。
この判断の背景、代替案、トレードオフは [ADR 0012](../adr/0012-consolidate-iac-security-scan-on-trivy-config.md) に記録します。

## Required 化の方針

Issue #226 の初期導入では、`TFLint` / `Trivy Config Scan` / `Gitleaks Secret Scan` を PR で自動実行するチェックとして追加します。
branch protection の required status checks にはすぐ追加しません。

ここでいう `job fail` と `required status check` は別のものです。

| 用語 | 意味 | 今回の扱い |
|---|---|---|
| `job fail` | GitHub Actions の job が失敗し、PR上で赤く表示される | `TFLint` / `Gitleaks Secret Scan` は検出時に fail。`Trivy Config Scan` は初期導入時点では fail させない |
| `required status check` | branch protection で、その check が成功しないとマージできないようにする設定 | #226 時点では3jobとも required にしない |

理由:

- `Trivy Config Scan` は既存設計の意図的な例外も検出する
- 既存 IaC に対する false positive / accepted risk の棚卸しが必要
- 実行時間と運用安定性を見てから required 化したほうが、日常PRを詰まらせにくい

required status checks への追加は、#228 で判断しました。
この段階的 required 化の判断背景、代替案、トレードオフは [ADR 0013](../adr/0013-promote-quality-checks-to-required-gradually.md) に記録します。

## #228 required 化判断

#227 は 2026年5月14日 15:25 JST にマージされました。
#228 では、観察期間後の 2026年5月22日 JST に、false positive・実行時間・PR運用への影響を確認しました。

### 実行結果

#227 以降の `PR Check` workflow 実行履歴を確認した結果、対象3jobはいずれも安定して完了していました。

| Job | 結果 | 実行時間 | 判断 |
|---|---:|---:|---|
| `TFLint` | 54 / 54 success | 平均19秒、最大26秒 | required 化する |
| `Gitleaks Secret Scan` | 54 / 54 success | 平均23秒、最大27秒 | required 化する |
| `Trivy Config Scan` | 54 / 54 success | 平均19秒、最大46秒 | required 化しない |

同期間に `PR Check` workflow 全体の失敗はありましたが、失敗した job は `Terraform Plan Artifact` であり、`TFLint` / `Gitleaks Secret Scan` / `Trivy Config Scan` ではありませんでした。

### 判断

`TFLint` は、観察期間中に false positive や実行時間の問題が見られず、Terraform / AWS provider 向けの実務 lint として PR を止める価値が高いため required status check に追加します。

`Gitleaks Secret Scan` は、secret 混入時に PR マージを止めるべき性質が強く、観察期間中も安定していたため required status check に追加します。

`Trivy Config Scan` は、引き続き review signal として扱います。
現在の workflow は `exit-code: 0` のため、HIGH / CRITICAL finding が存在しても job は成功します。
そのため `Trivy Config Scan` を required status check に追加しても、現状では finding を理由に PR を止める gate にはなりません。

`Trivy Config Scan` を blocking gate にする場合は、次の整理を先に行います。

- 参照頻度の低いアーカイブ資料を scan 対象に残すか、別管理に切り分けるか判断する
- Dockerfile の root user を修正するか accepted risk として扱うか判断する
- WAF 無効化、KMS / CMK、CloudTrail / Athena / SNS 暗号化の finding を修正対象・accepted risk・ignore 対象に分類する
- accepted risk / ignore の理由を docs に残したうえで、`exit-code: 1` への変更を別 Issue で検討する

### ロールバック

required 化後に運用上の問題が出た場合は、branch protection の required status checks から `TFLint` / `Gitleaks Secret Scan` を外します。
この docs 更新自体は該当 PR を revert して戻します。

branch protection は Git 管理外の GitHub 設定です。
そのため、docs の revert だけでは required status checks は戻りません。
設定変更後は次のコマンドで実設定を確認します。

```bash
gh api repos/:owner/:repo/branches/main/protection/required_status_checks \
  --jq '{strict, contexts}'
```

`TFLint` / `Gitleaks Secret Scan` を required status checks から外す場合は、`contexts` から2つを除いた一覧で branch protection を更新します。

```bash
jq -n '{
  strict: false,
  contexts: [
    "PR Policy Check",
    "Backend Lint & Build",
    "Frontend Build",
    "Terraform Format & Validate",
    "Commitlint"
  ]
}' \
  | gh api --method PATCH \
      repos/:owner/:repo/branches/main/protection/required_status_checks \
      --input -
```

## ローカル検証

```bash
# TFLint
tflint --init
tflint --recursive --config "$(pwd)/.tflint.hcl"

# Gitleaks
gitleaks git --no-banner --redact --config .gitleaks.toml

# Trivy Config
trivy config \
  --severity HIGH,CRITICAL \
  --exit-code 0 \
  --skip-dirs docs/worklogs \
  --skip-dirs docs/llm-repo-bundle \
  --skip-dirs client/dist \
  .
```

## 2026-05-14 時点の初期検証メモ

- `tflint --recursive --config "$(pwd)/.tflint.hcl"` は通過
- `gitleaks git --no-banner --redact --config .gitleaks.toml` は no leaks
- `trivy config` は Dockerfile の root user、WAF 無効化、security group egress などを検出
  - `public subnet` の `map_public_ip_on_launch = true` は Issue #231 / PR #242 で修正済み（2026-05-17）

`trivy config` の検出結果は初期導入時点ではレビュー補助として扱います。
コスト最適化やデモ用途で意図的に採用している設計も含まれるため、後続作業で accepted risk / 修正対象 / 除外対象を整理します。

### WAF 無効化の扱い

Trivy Config が検出する WAF 無効化は、現時点では即時修正対象ではなく accepted risk として扱います。
このプロジェクトはポートフォリオ / デモ用途で、通常は destroy 済みの停止運用を前提にしています。
WAF を常時有効化すると固定費が増え、短時間だけ起動するデモ環境では費用対効果が低いためです。

ただし、これは WAF が不要という判断ではありません。
`Trivy Config Scan` では引き続き review signal として検出を確認し、外部公開時間・アクセス量・攻撃面・デモ利用頻度が増えた場合は WAF 有効化を再検討します。
詳細な判断理由と再検討条件は [Security Design](../architecture/security-design.md#waf-%E7%84%A1%E5%8A%B9%E5%8C%96%E3%81%AE-accepted-risk) を参照してください。

### HTTP listener / origin protocol の扱い

Issue #234 で、外部公開面は HTTPS に寄せました。
CloudFront の API origin は `api.hamilcar-hannibal.click` への `https-only` に変更し、ALB の production traffic は 443 HTTPS listener へ寄せています。
ALB の 80 HTTP listener は application traffic を forward せず、HTTPS redirect 専用として維持します。
Blue/Green の test listener 8080 も HTTPS で TLS 終端します。

ALB から ECS target group への通信は HTTP のまま維持します。
ECS task は private subnet にあり、ingress は ALB security group から container port への通信に限定しているため、これは外部公開面ではなく内部経路として扱います。
今後 `trivy config` で HTTP listener / HTTP origin finding を確認する場合は、CloudFront origin の `https-only` と ALB 80 の redirect 専用化が崩れていないかを優先して見ます。

### Public ALB 直アクセス制限の扱い

Issue #232 で、ALB は internet-facing のまま維持しつつ、CloudFront 経由の API origin 通信だけを通す二段制限を追加しました。

- ALB security group の ingress は `0.0.0.0/0` ではなく、AWS managed prefix list `com.amazonaws.global.cloudfront.origin-facing` からの TCP `80-8080` に限定する
- CloudFront の ALB origin は `X-Hannibal-Origin-Verify` custom header を付ける
- ALB の 443 / 8080 listener rule は header が一致する場合のみ forward し、header がないリクエストは `403` を返す

`aws_lb.main.internal = true` は今回採用しません。
現在の CloudFront custom origin は public DNS の `api.hamilcar-hannibal.click` を使うため、internal ALB 化は CloudFront VPC origins を含む private origin 構成への移行として別 Issue で検討します。

CloudFront managed prefix list は weight 55 のため、80 / 443 / 8080 を個別 ingress rule にすると security group rule quota を超えやすくなります。
そのため TCP `80-8080` を1本の rule にまとめ、HTTP 層では secret header による listener rule でさらに制限します。

### 導入時に実施した検証

Issue #226 の実装時点で、ローカルで実行可能な範囲のチェックを実行しました。

| コマンド / チェック | 結果 | 備考 |
|---|---|---|
| `git diff --check` | pass | 末尾空白などの差分不備なし |
| workflow YAML parse | pass | `.github/workflows/pr-check.yml` / `security-scan.yml` を構文確認 |
| `actionlint .github/workflows/pr-check.yml` | pass | GitHub Actions workflow の静的検証 |
| `terraform fmt -check -recursive` | pass | Terraform formatting 確認 |
| `tflint --recursive --config "$(pwd)/.tflint.hcl" --format compact` | pass | ルート設定を明示して既存モジュールを検査 |
| `gitleaks git --no-banner --redact --config .gitleaks.toml` | pass | 639 commits を走査し no leaks |
| `trivy config --severity HIGH,CRITICAL --exit-code 0 ... .` | pass | findings は review signal として確認 |
| `npm test -- --runInBand` | pass | 既存 Jest unit test を確認 |

`npm run test:e2e` は現状 `AppModule` が TypeORM 経由で PostgreSQL に接続するため、ローカルDBなしでは失敗します。
これは今回の品質ゲート追加とは別に、テスト基盤整備の後続課題として扱います。
