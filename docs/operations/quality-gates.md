# Quality Gates

`terraform-hannibal` の PR で実行する品質ゲートと、各ツールの役割をまとめます。

## 目的

- Terraform / Dockerfile / Git 履歴を PR 時に自動確認する
- Terraform 公式チェックだけでは見つけにくい provider 固有のミス、IaC セキュリティ設定、secret 混入を早期に検出する
- DevOps ポートフォリオとして、単に CI を並べるのではなく、目的別に品質ゲートを設計していることを示す

## PR チェック

| Job | ツール | 役割 | 2026-05-22 時点の扱い |
|---|---|---|---|
| `Terraform Format & Validate` | `terraform fmt` / `terraform validate` | HCL の整形と Terraform 構成の基本整合性を確認 | required status check 対象 |
| `TFLint` | `tflint` | Terraform / AWS provider 向けの lint。非推奨設定、未使用宣言、provider 固有のミスを検出 | required status check 対象。検出時は fail |
| `Trivy Config Scan` | `trivy config` | Terraform / Dockerfile などの IaC・設定ミスを検出 | PR で自動実行。review signal として扱い、検出しても fail しない |
| `Gitleaks Secret Scan` | `gitleaks` | Git 履歴に混入した API key / token / password などの secret を検出 | required status check 対象。検出時は fail |

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

required status checks への追加は、#228 で判断しました。

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

- 旧 CloudFormation 資産を scan 対象に残すか、別管理に切り分けるか判断する
- Dockerfile の root user を修正するか accepted risk として扱うか判断する
- WAF 無効化、KMS / CMK、CloudTrail / Athena / SNS 暗号化の finding を修正対象・accepted risk・ignore 対象に分類する
- accepted risk / ignore の理由を docs に残したうえで、`exit-code: 1` への変更を別 Issue で検討する

### ロールバック

required 化後に運用上の問題が出た場合は、branch protection の required status checks から `TFLint` / `Gitleaks Secret Scan` を外します。
この docs 更新自体は該当 PR を revert して戻します。

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
- `trivy config` は Dockerfile の root user、CloudFormation 旧資産、WAF 無効化、security group egress などを検出
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
