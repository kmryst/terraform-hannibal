# GitHub Flow Guardrails

`terraform-hannibal` の GitHub フローを、少人数・dev中心運用に合う軽さを保ちながら、仕組みで担保するための設計意図をまとめた文書です。

運用ルールの正本は [CONTRIBUTING.md](../../CONTRIBUTING.md) です。この文書では、採用方針の理由、未採用案、将来の再検討条件を補足します。

## 3 リポジトリ間の位置づけ

時系列では、`terraform-hannibal` は `idp-golden-path` より先に作られた実証リポジトリです。
ただし現在の方針としては、`terraform-hannibal` / `ticket-c2c-platform` で実証した Issue / PR 駆動、AI Agent 運用、CI ガードレール、ADR 運用を `idp-golden-path` が golden path として抽象化し、3 リポジトリをその型へ収束させていきます。

そのため、このリポジトリの GitHub Flow も、単独のローカルルールではなく、`idp-golden-path` が配布・標準化するリポジトリ運用ガードレールへ収束させる対象として扱います。
Terraform / AWS / SRE 実践としての固有判断はこのリポジトリに残し、横断的な運用ルールは golden path 側へ寄せます。

## 現時点の技術的な未収束点

2026-07-13 時点では、方針と docs は `idp-golden-path` の型へ寄せていますが、技術実装はまだ完全には収束していません。

- Commitlint は `idp-golden-path` の reusable workflow を `@v1` で消費する薄い caller workflow に移行済み（Issue #495）。PR Policy Check / Gitleaks / Sync Labels はこのリポジトリ内のローカル workflow のまま。
- 移行済みの Commitlint の required status check 名は、caller/callee 合成名（`commitlint / Commitlint`）になる。caller job には `name:` を付けず job id にフォールバックさせている（callee と同名にすると `Commitlint / Commitlint` のように文字列がそのまま重複し可読性を損なうため。idp-golden-path#106参照）。
- caller workflow の `concurrency.group` は、callee（idp-golden-path 側の reusable workflow）と同一の文字列にしてはならない。同一名にすると GitHub Actions が caller/callee 間のデッドロックと判定し job を1つも起動せず run をキャンセルする。caller 側は `-caller` サフィックスを付けて区別する（ticket-c2c-platform#294 / idp-golden-path#106参照）。
- Markdown Lint / Issue Template Check など、service baseline skeleton が持つ共通 CI ガードレールは未導入または未整合である。導入や required 化は、運用負荷を見て別 Issue で判断する。
- helper scripts は共通化途上であり、`idp-golden-path` の `scripts/github/lib/common.sh` 形式には揃っていない。
- Terraform plan / apply / destroy、TFLint、Trivy Config Scan などの Terraform / AWS 固有 workflow は、このリポジトリ固有の責務として残す。

## 目的

- `Issue -> Branch -> PR -> Merge` を推奨ではなくガードレールで支える
- AI Agent / CLI / API を使っても、最終的なIssue / PR品質が崩れないようにする
- dev中心運用では過剰な承認フローを避け、人間確認は本当に効く場所へ寄せる

## 設計原則

- 入口の Issue は完全遮断ではなく、作成後のチェックで整える
- 出口の PR は CI で強く止める
- AI は下書きと整理を補助し、人間は起票判断・レビュー判断・反映判断を担う
- ラベルは飾りではなく、分類と判断のためのメタデータとして扱う

## 採用方針

### 実装済みまたは今回整備するもの

- `main` は branch protection で direct push 禁止、PR必須、required status checks 必須、squash merge only
- Issue / PR の共通必須ラベルは `type / area / risk / cost`
- PR 本文には `Closes / Fixes / Refs #<issue番号>` を必須にする
- Issue の必須本文項目は `目的 / 対象 / 受け入れ条件`
- Web UI の Issue Forms は 1 本に寄せ、`目的 / 対象 / 受け入れ条件` と `type / area / risk / cost` を同じフォームで扱う
- Issue の自動チェックは本文とラベルの両方を見て、未整備なら `needs-template` を付ける
- Issue 本文に専用の運用区分欄は追加せず、軽運用 / 厳密運用の判定は起票前プランと PR 作成前プランで確認する
- PR テンプレの `目的 / 変更内容 / 影響範囲` は推奨に留め、厳密運用PRでは `ロールバック` を必須にする
- PR title と PR 内コミットメッセージは `Commitlint` job で Conventional Commits 形式を検査する
- `TFLint` と `Gitleaks Secret Scan` は #228 で required status checks に追加した
- `Trivy Config Scan` は HIGH / CRITICAL finding を review signal として表示するが、#228 時点では blocking gate にしない

### 軽運用 / 厳密運用

軽運用では、Issue と PR の本文は最小限に保ちます。その代わり、Issueリンク、ラベル、CI を必須にして、最低限の構造を揃えます。
Issue 本文の必須項目を増やすと、軽微な docs / CI 修正や AI Agent / CLI 起票の負担が増えやすいため、運用区分は本文項目としては持たせません。
代わりに、人間または AI Agent が起票前プランでラベル・変更対象・変更内容を見て判断します。

厳密運用は、次のいずれかに当てはまるものです。

- `risk:medium/high`
- `cost:medium/large`
- `terraform/**`
- `.github/workflows/**`
- `scripts/deployment/**`
- `scripts/validation/**`
- IAM / OIDC / Permission Boundary
- Secrets / Network / Security
- deploy / destroy に関わる変更
- 運用環境に影響する変更
- コスト影響がある変更
- ロールバックを考える必要がある変更

厳密運用PRでは、`ロールバック` を本文に必須にします。ここで求めるのは見出しだけではなく、実際にどう戻すかが分かる最低限の内容です。

### AI Agent 運用

- 通常Issueも AI Agent / CLI / API から起票される前提で設計する
- Web UI 起票では `.github/ISSUE_TEMPLATE/feature_request.yml` を使い、フォーム回答から `type / area / risk / cost` を同期する
- ただし、AI Agent は原則として起票前に Issue プランを提示する
- Issue プランには、タイトル案、`目的`、`対象`、`受け入れ条件`、推奨ラベルとしての `type/area/risk/cost`、軽運用 / 厳密運用の判定と理由、`使用ヘルパー: ./scripts/github/create-issue-with-labels.sh` を明示して含める
- PR も同様に、いきなり作成せず先に PR プランを提示する
- PR プランには、タイトル案、`目的`、`変更内容`、`影響範囲`、`Closes/Fixes/Refs #<issue番号>`、推奨ラベルとしての `type/area/risk/cost`、`使用ヘルパー: ./scripts/github/create-pr-with-labels.sh`、軽運用 / 厳密運用の判定と理由、厳密運用の場合は `ロールバック` が必須かどうかを明示して含める
- 起票後は GitHub Actions が最終チェックする

Issue / PR のどちらも、AI Agent は下書きと整理を担当し、人間が起票前に内容を確認します。これにより、GitHub Actions の機械チェックに入る前に、意図のズレや過不足を減らします。
`使用ヘルパー` は起票前プランで確認するための項目であり、GitHub 上の最終 Issue / PR 本文に毎回含める必須項目ではありません。

実装についても同様に、ブランチを切った後・コードを書く前に実装計画を提示し、人間が確認してから着手します。

採用理由:

- コードを書いてから方針のズレを発見すると手戻りコストが高い
- 計画段階であれば、変更対象・影響範囲・リスクの認識合わせが軽い
- Issue / PR プランと同じ「先に確認、後に実行」の一貫した流れにできる

### commitlint 方針

commitlint / Conventional Commits の運用ルール正本は [CONTRIBUTING.md](../../CONTRIBUTING.md) です。
この文書では、なぜ PR title と PR 内コミットメッセージの両方を検査するかを補足します。

このプロジェクトは squash merge only を前提にしているため、main に残る履歴の見出しは PR title の影響を受けます。
そのため、PR title を Conventional Commits 形式で検査します。

一方で、AI Agent がコミットを作成する運用では、PR 内コミットメッセージも品質ゲートに含めることで、`wip` や `update files` のような曖昧な履歴を PR に載せないようにします。
これは人間の作業を重くするためではなく、AI Agent が一定の運用品質で履歴を残すためのガードレールです。

`Commitlint` job は独立した check として追加します。
これにより、ラベル・Issueリンク・ロールバック欄を見る `PR Policy Check` と、コミット/PR title の形式検査を分離し、失敗時の原因を読み取りやすくします。
required status check として扱う場合は、workflow 追加後に GitHub の branch protection 設定も同期します。

#415 では、PR 作成ヘルパーによる label 付与で重い CI が重複実行されないよう、`PR Policy Check` を `.github/workflows/pr-policy-check.yml` に、`Commitlint` を `.github/workflows/pr-commitlint.yml` に分離しました。
`PR Policy Check` は `opened` / `synchronize` / `reopened` / `edited` / `labeled` / `unlabeled` で実行し、label や本文の変更をすぐ検査します。
`Commitlint` は PR title 変更を検知するため `edited` でも実行しますが、`labeled` / `unlabeled` では workflow 自体を起動しません。
backend / frontend / Docker / Terraform / TFLint / Trivy / Gitleaks は `.github/workflows/pr-check.yml` に残し、`opened` / `synchronize` / `reopened` のみで実行します。

### PR 品質ゲート required 化方針

#227 で追加した `TFLint` / `Trivy Config Scan` / `Gitleaks Secret Scan` は、初期導入時点では branch protection の required status checks に含めず、観察期間後に #228 で判断しました。

#228 では、#227 マージ後の `PR Check` workflow 実行履歴を確認し、`TFLint` と `Gitleaks Secret Scan` を required status checks に追加しました。
どちらも観察期間中の実行が安定しており、検出時に PR を止める価値が高いためです。

`Trivy Config Scan` は #228 時点では required status check に追加しません。
現在の workflow は `exit-code: 0` で、HIGH / CRITICAL finding があっても job を成功させます。
既存の finding には、Dockerfile root user、WAF 無効化、KMS / CMK 系の accepted risk 候補が含まれるため、blocking gate にする前に修正対象・accepted risk・ignore 対象を整理します。

この段階的 required 化の判断背景、代替案、トレードオフは [ADR 0013](../adr/0013-promote-quality-checks-to-required-gradually.md) に記録します。

## 未採用案と理由

### approval 常時必須

今は採用しません。

理由:

- 少人数運用では重い
- 形式的な承認になりやすい
- 代わりに PR必須、必須CI、Issueリンク、ラベル、人間確認で担保できる

### CODEOWNERS 即導入

今は採用しません。

理由:

- 現状は責任分担の実益が薄い
- 少人数では運用コストが先に立つ

### dev への Environment 承認

今は採用しません。

理由:

- `deploy.yml` は手動実行で、押す人間の判断がすでに入る
- `destroy.yml` は `workflow_dispatch + DESTROY` 入力で十分強い確認になっている
- dev中心運用では二重承認が過剰になりやすい

### 全PRで重い本文チェック

今は採用しません。

理由:

- 軽微な docs / CI 修正でも過剰に重くなる
- 全PRで必要なのは本文の完璧さより、Issueリンク・ラベル・CI の方が優先度が高い

## Terraform plan 方針

**現在の判断: PR Terraform Plan Artifact は #410 で一時停止中**

state 分割後の `terraform/service` は `terraform_remote_state` で `network` / `database` の outputs を参照します。
dev 環境は通常 destroy 済みのため、参照先 state に outputs がなく、`This object does not have an attribute named "vpc_id"` のようなエラーで service plan が構造的に失敗します。

この状態の `Terraform Plan Artifact` は required status check ではないものの、通常運用で失敗し続けるため、レビュー補助ではなく CI noise になります。
そのため #410 では、壊れた signal を残さず、`Terraform Plan Change Detection` / `Terraform Plan Artifact` job を `pr-check.yml` から一時的に外します。

`terraform fmt/validate` は軽量・常時の静的ガード、`terraform plan` は実state を使う差分確認として役割を分けます。
ただし、PR workflow 上の plan artifact は再設計まで停止します。

PR plan を再導入する場合は、次の条件を満たしてから判断します。

- destroy 済みが通常である前提でも意味のある plan artifact を出せる
- `terraform_remote_state` の outputs 不足で通常失敗しない
- PR plan 用 composite root module など、`network -> database -> service` 相当を 1 つの Terraform graph として評価できる構成を検討する
- composite root を採用する場合は、実運用 root modules との drift 対策を含める
- fork PR では AWS Role を assume しない
- apply / destroy / write 系権限を PR workflow に持たせない

PR plan 用 AWS Role / OIDC 権限の詳細設計は [pr-terraform-plan-role-design.md](./pr-terraform-plan-role-design.md) に分けます。
Role 自体は foundation 側で保持しますが、#410 時点では PR workflow からは使いません。

### Terraform plan の required status check 方針

**現在の判断: PR plan job 自体を一時停止しているため required 化しない（#410 時点）**

理由:

- destroy 済み通常運用で `terraform_remote_state` outputs が存在せず、service plan が構造的に失敗する
- required ではない review signal が通常失敗し続けると、CI の signal quality が下がる
- skip fallback は CI の赤を消せるが、destroy 済み通常運用ではほぼ毎回 skip になり、plan artifact のレビュー価値が低い
- sequential plan は `network` の plan 結果を `database` / `service` の remote state outputs として渡せないため、根本解決にならない
- composite root module 案は有力だが、実運用 root modules との drift 対策が必要であり、別途設計して再導入する

**skip の扱い**

PR plan job は #410 時点で workflow から外しているため、`terraform/**` 変更なしや fork PR による plan skip は発生しません。
PR plan を再導入する場合は、skip が required status check と衝突しないよう、必要に応じて gate job を置きます。

**plan 失敗時のマージ可否**

PR plan job は #410 時点で実行していません。
Terraform 変更の PR では、`Terraform Format & Validate` / `TFLint` / `Trivy Config Scan` / `Gitleaks Secret Scan` を PR gate / review signal として使います。
実 state を読む plan 差分確認が必要な場合は、deploy 前後の手動確認または後続の再導入設計で扱います。

**将来 required 化する場合の方針**

生の `Terraform Plan Artifact` job を直接 required にせず、**gate job を新設してそちらを required 対象にする**。

gate job の役割:

- plan が skip された場合（terraform 変更なし・fork PR）→ success を返す
- plan が成功した場合 → success を返す
- plan が失敗した場合 → fail を返す

これにより skip を gate job で吸収でき、required check と整合が取れる。
branch protection の更新は、PR plan の再導入後に gate job が安定してから後続 Issue で別途判断する。

**現在の required status checks（参考）**

`PR Policy Check` / `Commitlint` / `Backend Lint & Build` / `Frontend Build` / `Terraform Format & Validate` / `TFLint` / `Gitleaks Secret Scan`

`PR Policy Check` は `.github/workflows/pr-policy-check.yml` から、`Commitlint` は `.github/workflows/pr-commitlint.yml` から、その他の PR gate / review signal は `.github/workflows/pr-check.yml` から実行する。
workflow を分割しても、branch protection が参照する required status check の context 名は変更しない。

`Trivy Config Scan` は required に含まれていない。
`Terraform Plan Change Detection` / `Terraform Plan Artifact` は #410 で workflow から一時的に削除している。

### deploy workflow と PR gate の責務分離

`deploy.yml` は `workflow_dispatch` で `main` から手動実行する CD workflow として扱います。
backend/frontend の build・test は PR gate（`pr-check.yml`）に集約し、deploy workflow では再実行しません。

この分離により、品質保証は merge 前の PR に寄せ、merge 後の deploy は Terraform apply、frontend build、S3 sync、ECR push、CodeDeploy へ集中させます。

## 将来の再検討条件

### approval 再検討条件

- 常時レビュー担当が2名以上いる
- `terraform/` や `.github/workflows/` の責任分担が明確
- 緊急変更でも相互レビューできる体制がある
- 本番相当の共有環境を継続運用する段階に入る

### CODEOWNERS 再検討条件

- 複数人で責任分担する領域オーナーが明確になった
- `terraform/` と `.github/workflows/` を継続的に見る人が複数いる
- レビュー責任を GitHub 上で明示する価値が、運用コストを上回る

### deploy / destroy 承認の再検討条件

- 共有の本番相当環境を継続運用する
- 実行者と確認者を分けられる体制になる
- dev ではなく、誤実行コストの高い環境へ適用する
