# 0019. Terraform state を PR 単位で分離する Preview Environment を採用する

## ステータス

Accepted

## 日付

2026-06-20

## 決定内容

PR ごとに一時的な AWS 検証環境を作れるように、Terraform state を PR 番号単位で分離する Preview Environment の設計を採用する。

Preview Environment は Git branch ではなく、PR 番号に紐づく AWS 上の一時環境である。PR は通常どおり `main` へ merge し、`preview-pr-<number>` のような名前の branch を作ったり、merge 先を変えたりしない。

Preview 用の Terraform root module は `terraform/environments/preview/` として追加する方針とする。ただし、PR ごとのディレクトリは作らない。

- 作る: `terraform/environments/preview/`
- 作らない: `terraform/environments/preview-pr-101/`

PR ごとの差分は、同じ preview root module に対して backend key と入力変数を変えることで表現する。

| 項目 | PR #101 の例 |
|---|---|
| AWS environment name | `preview-pr-101` |
| Terraform backend key | `preview/pr-101/terraform.tfstate` |
| AWS resource prefix | `hannibal-pr-101` |

初期実装では、PR 作成時に preview 環境を自動作成しない。必要な PR だけ、GitHub Actions の `workflow_dispatch` で PR 番号を入力して手動 create / destroy する方針から始める。destroy workflow は create と同じ backend key を使い、destroy 対象を間違えないように確認入力を必須にする。

staging / production は PR ごとに複製しない。共有環境として扱い、deploy は concurrency control や承認で直列化する。

## 背景

現在の `terraform-hannibal` は、`terraform/environments/dev` が実質的な共有検証環境として使われている。dev 環境は通常 destroy 済みにし、必要な時だけ起動する運用である。

少人数運用では共有 dev 環境 1 つでも回せるが、複数人または複数 PR が同時に Terraform / アプリ変更を検証する場合、同じ Terraform state と同じ AWS 環境を奪い合う。50 人が同時に PR を出すような状況では、共有 dev 環境だけでは検証待ち、state lock、リソース名衝突、途中 destroy などの問題が起きる。

PR ごとに Preview Environment を分けると、各 PR は自分専用の state と AWS リソース名 prefix を持てる。これにより、PR 単体の Terraform plan / apply / 動作確認を並列化しやすくなる。

一方で、Preview Environment はあくまで PR 単体の確認に強い。別の PR が先に `main` へ入った後、自分の PR が最新 `main` と組み合わさって動くことは、preview 環境だけでは保証できない。最新 `main` との統合確認は、required checks、branch update、Merge Queue / Merge Group CI、staging deploy などの別レイヤーで扱う。

## 検討した選択肢

### 採用する選択肢

#### `terraform/environments/preview/` を追加し、PR ごとは backend key / 変数で分ける

- 長所: preview 固有の lifecycle、命名、低コスト設定、destroy 前提を root module 境界で表現できる
- 長所: PR ごとにディレクトリを増やさず、同じ root module と別 state key で並列環境を作れる
- 長所: dev が本番もどきの共有検証環境を兼ねている現状と、PR 単体確認用の短命環境を分離できる
- 短所: preview 用 root module、workflow、IAM Role、runbook を追加で設計する必要がある

### 採用しない選択肢

#### 共有 dev 環境だけを使い続ける

- 長所: 追加する Terraform root module や workflow が少なく、運用が単純
- 長所: AWS リソース数とコストを増やさずに済む
- 短所: 複数 PR の同時検証で state、AWS リソース、deploy / destroy の競合が起きる
- 短所: ある PR の検証中に別の PR が dev を変更・destroy すると、確認結果の信頼性が下がる

#### 既存の `terraform/environments/dev` を preview 兼用にする

- 長所: 最小差分で実装でき、既存 dev root module をそのまま流用しやすい
- 長所: 初期の Terraform コード重複を避けられる
- 短所: dev と preview は lifecycle、命名、destroy 前提、コスト制約が異なるため、条件分岐が増えやすい
- 短所: backend key の切り替えや `project_name` / `environment` の上書きが dev 運用と混ざり、誤操作時の影響範囲が読みづらくなる

#### PR ごとに `terraform/environments/preview-pr-<number>/` を作る

- 長所: ファイル構造だけ見れば PR ごとの環境が分かりやすい
- 短所: PR ごとにディレクトリや設定ファイルが増え、短命環境の管理方法として重い
- 短所: PR close / merge 後の削除漏れや、同じ構成のコピー差分が増えやすい

#### staging / production も PR ごとに複製する

- 長所: PR ごとの独立性を production 相当まで広げられる
- 短所: staging / production は統合検証・本番提供の共有環境であり、PR 単位に増やす対象ではない
- 短所: コスト、AWS quota、承認、監査、データ管理の負荷が大きすぎる

## 採択理由

Preview Environment は dev / staging / production と lifecycle が異なる。preview は PR 単体を短期間確認し、不要になったら destroy する前提の環境である。共有 dev は開発・デモ・本番もどきの確認を兼ねる環境であり、staging / production は共有の統合・本番環境として直列 deploy する対象である。

そのため、preview は `terraform/environments/preview/` として専用 root module を持たせる。一方で、PR ごとに root module ディレクトリを増やす必要はない。PR 番号ごとに backend key を `preview/pr-<number>/terraform.tfstate` へ分け、resource prefix を `hannibal-pr-<number>` のように分ければ、同じ root module から複数の一時環境を扱える。

既存の state key 命名規則 `environments/<env>/terraform.tfstate` は、`dev` / `staging` / `prod` のような共有環境を対象にする。preview は同じ環境タイプの下に PR 番号単位の一時インスタンスを複数作るため、`preview/pr-<number>/terraform.tfstate` という別 namespace を使う。

初期から PR 作成時に自動 apply すると、不要な preview 環境が大量作成され、destroy 漏れや AWS quota 超過を招きやすい。まずは `workflow_dispatch` の手動 create / destroy で必要な PR だけを対象にし、実運用のコスト・所要時間・失敗パターンを見てから自動化を検討する。

## 影響

- `terraform/environments/preview/` を preview 用 root module として追加する方針になる
- preview の state key は `preview/pr-<number>/terraform.tfstate` とする
- preview の AWS environment name は `preview-pr-<number>` とする
- preview の AWS resource prefix は `hannibal-pr-<number>` とする
- PR ごとの `terraform/environments/preview-pr-<number>/` は作らない
- staging / production は PR ごとに複製せず、共有環境として直列 deploy する
- preview create / destroy workflow は、同じ backend key を使う必要がある
- preview create / destroy は deploy / destroy に関わるため、workflow や IAM 実装時は厳密運用で扱う

## リスクと注意点

- destroy 漏れ: PR close / merge 後に preview 環境を消し忘れると、AWS リソースと state が残り続ける
- コスト: RDS、ALB、NAT Gateway、CloudFront などを preview ごとに作る場合、同時稼働数に比例してコストが増える
- AWS quota: VPC、ALB、Target Group、EIP、RDS、IAM Role などの上限に近づく可能性がある
- IAM Role: preview create / destroy には write 権限が必要であり、PR plan 用 read-only Role とは分けて設計する必要がある
- state key 誤指定: create と destroy で backend key がずれると、意図した preview 環境を消せない、または別環境を操作するリスクがある
- resource naming: `hannibal-pr-<number>` を prefix にしても、AWS リソースごとの長さ制限やグローバル一意制約を確認する必要がある
- resource prefix 差異: 共有環境の `nestjs-hannibal-3-*` と preview の `hannibal-pr-*` が同一アカウントに混在するため、タグと命名で環境タイプを識別できるようにする
- 統合保証: preview は PR 単体確認用であり、最新 `main` との統合保証は required checks、Merge Queue / Merge Group CI、staging deploy などで別途扱う

## 今回のスコープ外

- `terraform/environments/preview/` の実装
- preview create workflow の実装
- preview destroy workflow の実装
- preview 用 IAM Role / Permission Boundary の実装
- PR close / merge 後の自動 destroy
- destroy 漏れ検知・通知
- Merge Queue / Merge Group CI の導入
- staging 環境の本格構築
- production 環境の本格構築
- GitHub Environments による承認
- preview 同時稼働数上限の自動 enforcement

## 後続フェーズ

1. `terraform/environments/preview/` を追加し、`environment = "preview"` と `pr_number` から preview 用の environment name / resource prefix を作れるようにする
2. `workflow_dispatch` で PR 番号を受け取り、`preview/pr-<number>/terraform.tfstate` を backend key として使う preview create workflow を追加する
3. 同じ backend key と確認入力を使う preview destroy workflow を追加する
4. preview 用 IAM Role / Permission Boundary を設計し、dev deploy / destroy Role や PR plan Role と責務を分ける
5. destroy 漏れ検知、PR close / merge 後の自動 destroy、同時稼働数上限を検討する
6. staging / production を独立した共有環境として整備し、直列 deploy と承認を設計する

## 関連

- [Issue #386](https://github.com/kmryst/terraform-hannibal/issues/386)
- [ADR 0014: Terraform foundation / environments のルートモジュールと state を分離する](./0014-separate-terraform-foundation-and-environment-state.md)
- [ADR 0005: deploy/destroy 用 Role と PR plan 用 Role を分離する](./0005-separate-cicd-and-pr-plan-roles.md)
- [ADR 0008: オンデマンド起動 / 通常 destroy 運用を採用する](./0008-on-demand-startup-and-routine-destroy-operation.md)
- [Terraform 環境分離設計](../terraform-environments.md)
