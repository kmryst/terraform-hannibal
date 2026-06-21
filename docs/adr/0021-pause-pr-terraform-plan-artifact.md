# 0021. PR Terraform Plan Artifact を一時停止する

## ステータス

Accepted

## 日付

2026-06-21

## 決定内容

PR workflow の `Terraform Plan Change Detection` / `Terraform Plan Artifact` を一時停止し、`pr-check.yml` から削除する。

`HannibalPRPlanRole-Dev` / `HannibalPRPlanBoundary-Dev` / `HannibalPRPlanPolicy-Dev` は foundation 側の永続リソースとして保持するが、#410 時点では PR workflow から assume しない。

PR 時の Terraform 自動確認は、当面次の check に寄せる。

- `Terraform Format & Validate`
- `TFLint`
- `Trivy Config Scan`
- `Gitleaks Secret Scan`

PR plan を再導入する場合は、destroy 済み通常運用でも意味のある plan artifact を出せる構成を設計し、実運用 root modules との drift 対策を含めて判断する。

## 背景

ADR 0020 で環境 state を `network` / `database` / `service` / `cdn` に分割した。
分割後の `terraform/service` は、`data.terraform_remote_state.network` / `data.terraform_remote_state.database` で上流 state の outputs を参照する。

このプロジェクトの dev 環境は通常 destroy 済みであり、必要なときだけ deploy する。
destroy 済み状態では、`network/terraform.tfstate` / `database/terraform.tfstate` に `vpc_id` や `db_instance_endpoint` などの outputs が存在しない。
そのため `terraform/service` の plan は `This object does not have an attribute named "vpc_id"` のようなエラーで構造的に失敗する。

分割前は 1 つの state / root module で全リソースを評価していたため、destroy 済みでも「全作成 plan」として成立した。
分割後は service 単体 plan が「上流 state に outputs があること」を前提にするため、通常 destroy 済み運用と噛み合わなくなった。

`Terraform Plan Artifact` は required status check ではないが、通常運用で失敗し続ける review signal は CI の signal quality を下げる。
「赤いが無視してよい check」を残すより、一時停止して再設計条件を明文化する方が健全である。

## 検討した選択肢

### 現状維持

- 長所: 既存 workflow を変更しない
- 短所: destroy 済み通常運用で plan が構造的に失敗し続ける
- 短所: required ではない review signal が noise になり、CI 失敗への注意が鈍る

### 上流 outputs がない場合に service plan を skip する

- 長所: CI の赤は止められる
- 長所: workflow 変更だけで済み、実装コストが小さい
- 短所: dev が通常 destroy 済みのため、ほぼ毎回 skip になり、plan artifact のレビュー価値が低い
- 短所: plan 差分が確認できない状態を「成功」に見せやすい

### `network -> database -> service` の順に plan する

- 長所: 実運用の apply 順序に近い
- 短所: Terraform の plan 結果は state outputs として次段に渡らない
- 短所: `network` を plan しても apply しない限り、`database` / `service` が読む remote state outputs は増えない
- 短所: destroy 済み通常運用での根本解決にならない

### PR plan 専用 composite root module を追加する

- 長所: `network -> database -> service` 相当を 1 つの Terraform graph として評価できる
- 長所: `terraform_remote_state` outputs に依存せず、destroy 済みでも全作成 plan として成立する
- 長所: このプロジェクトの通常 destroy 済み運用と最も整合する
- 短所: 実運用 root modules と composite root module の module wiring / variables / root resource が drift するリスクがある
- 短所: drift 対策、CI validate、module/resource inventory 比較などを合わせて設計する必要がある
- 短所: 初回対応としては作業量が大きい

### PR Terraform Plan Artifact を一時停止する

- 長所: 壊れた review signal を CI から外し、PR check の signal quality を保てる
- 長所: 再導入条件を明文化し、重い設計を後続に分離できる
- 長所: required status checks には影響しない
- 短所: PR 上で自動 plan artifact を確認する習慣が一時的に消える
- 短所: 再導入条件を明記しないと、停止が長期化しやすい

## 採択理由

PR plan 専用 composite root module は有力だが、実運用 root modules との drift 対策を伴う設計が必要であり、#410 の即時対応としては重い。

一方、現状の `Terraform Plan Artifact` は通常 destroy 済み運用で構造的に失敗するため、review signal として信頼できない。
required ではないとはいえ、失敗し続ける job を残すと、CI failure の意味が薄まり、本当に対応すべき失敗への注意が下がる。

そのため、#410 では `Terraform Plan Change Detection` / `Terraform Plan Artifact` を一時停止する。
これは PR plan を不要と判断したのではなく、現在の実装が通常運用と噛み合っていないため、意味のある artifact を出せる設計にしてから再導入する判断である。

## 影響

- `pr-check.yml` から `Terraform Plan Change Detection` / `Terraform Plan Artifact` が削除される
- PR workflow は `HannibalPRPlanRole-Dev` を assume しなくなる
- `HannibalPRPlanRole-Dev` / Boundary / Policy は foundation 管理の永続リソースとして残す
- Terraform 変更 PR では、自動 plan artifact の代わりに `terraform fmt` / `terraform validate` / `TFLint` / `Trivy Config Scan` / `Gitleaks Secret Scan` を確認する
- 実 state を使った plan 差分確認は、PR plan 再導入まで deploy 前後の手動確認または個別運用で扱う

## 再開条件

PR Terraform Plan Artifact を再導入する場合は、少なくとも次を満たす。

- destroy 済み通常運用でも plan artifact が構造的に失敗しない
- `terraform_remote_state` outputs 不足を通常系として扱える
- composite root module を採用する場合は、初期 scope を `network + database + service` に絞る
- composite root module は既存 `terraform/modules/*` を直接参照し、fork/copy module を作らない
- composite root module も `terraform fmt` / `init -backend=false` / `validate` の対象にする
- 実運用 root modules と composite root module の module/resource inventory や重要 wiring の drift 検知を設計する
- fork PR では AWS Role を assume しない
- PR workflow に apply / destroy / write 系権限を持たせない

## 関連

- [Issue #410](https://github.com/kmryst/terraform-hannibal/issues/410)
- [ADR 0005: deploy/destroy 用 Role と PR plan 用 Role を分離する](./0005-separate-cicd-and-pr-plan-roles.md)
- [ADR 0013: 品質チェックを観察期間後に段階的 required 化する](./0013-promote-quality-checks-to-required-gradually.md)
- [ADR 0020: 環境 state を責務単位で分割する](./0020-split-environment-state-by-responsibility.md)
- [GitHub Flow Guardrails](../operations/github-flow-guardrails.md)
- [Quality Gates](../operations/quality-gates.md)
- [PR Terraform Plan Role Design](../operations/pr-terraform-plan-role-design.md)
