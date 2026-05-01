# GitHub Flow Guardrails

`terraform-hannibal` の GitHub フローを、少人数・dev中心運用に合う軽さを保ちながら、仕組みで担保するための設計意図をまとめた文書です。

運用ルールの正本は [CONTRIBUTING.md](../../CONTRIBUTING.md) です。この文書では、採用方針の理由、未採用案、将来の再検討条件を補足します。

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

- 対象パスは `terraform/**`
- 実stateを使う
- `-refresh=true`
- `-lock=false`
- 出力は `artifact + Job Summary`
- PRコメント自動投稿は初回実装では行わない
- AWS認証は PR plan 専用の read-only Role を使い、deploy / destroy 用の `HannibalCICDRole-Dev` は使わない

`terraform fmt/validate` は軽量・常時の静的ガード、`terraform plan` は実state を使う差分確認として役割を分けます。

`-lock=false` を採るのは、PR plan を読み取り中心の確認として扱うためです。ただし、deploy 中の一時状態を読む可能性があるため、PR plan は最終確定値ではなくレビュー補助として扱います。

このプロジェクトでは dev 環境を通常 destroy 済みにしておき、人に見せる時だけ deploy してすぐ destroy します。そのため PR plan の全作成差分は正常系として扱い、drift 検知ではなく再構築予行演習として読むのが基本です。

PR plan 用 AWS Role / OIDC 権限の詳細設計は [pr-terraform-plan-role-design.md](./pr-terraform-plan-role-design.md) に分けます。

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
