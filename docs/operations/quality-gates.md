# Quality Gates

`terraform-hannibal` の PR で実行する品質ゲートと、各ツールの役割をまとめます。

## 目的

- Terraform / Dockerfile / Git 履歴を PR 時に自動確認する
- Terraform 公式チェックだけでは見つけにくい provider 固有のミス、IaC セキュリティ設定、secret 混入を早期に検出する
- DevOps ポートフォリオとして、単に CI を並べるのではなく、目的別に品質ゲートを設計していることを示す

## PR チェック

| Job | ツール | 役割 | 初期導入時の扱い |
|---|---|---|---|
| `Terraform Format & Validate` | `terraform fmt` / `terraform validate` | HCL の整形と Terraform 構成の基本整合性を確認 | required status check 対象 |
| `TFLint` | `tflint` | Terraform / AWS provider 向けの lint。非推奨設定、未使用宣言、provider 固有のミスを検出 | PR で自動実行し、検出時は fail |
| `Trivy Config Scan` | `trivy config` | Terraform / Dockerfile などの IaC・設定ミスを検出 | PR で自動実行。初期導入時点では review signal として扱い、検出しても fail しない |
| `Gitleaks Secret Scan` | `gitleaks` | Git 履歴に混入した API key / token / password などの secret を検出 | PR で自動実行し、検出時は fail |

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

required status checks への追加は、#228 で判断します。

#228 では、#227 マージから約1週間後の **2026年5月21日 JST 目安**で、false positive・実行時間・PR運用への影響を確認し、`TFLint` / `Gitleaks Secret Scan` / `Trivy Config Scan` を required 化するか判断します。
ただし `Gitleaks` で secret 検出、または `TFLint` で明確な設定ミスが出た場合は、2026年5月21日を待たずに優先判断します。

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
- `trivy config` は Dockerfile の root user、CloudFormation 旧資産、WAF 無効化、HTTP ALB listener、public subnet、security group egress などを検出

`trivy config` の検出結果は初期導入時点ではレビュー補助として扱います。
コスト最適化やデモ用途で意図的に採用している設計も含まれるため、後続作業で accepted risk / 修正対象 / 除外対象を整理します。

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
