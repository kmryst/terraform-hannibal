# 0005. deploy/destroy 用 Role と PR plan 用 Role を分離する

## ステータス

Accepted

## 日付

2026-05-31

## 決定内容

GitHub Actions から使う AWS Role は、main branch の deploy / destroy 用 `HannibalCICDRole-Dev` と、pull_request の Terraform plan 用 `HannibalPRPlanRole-Dev` に分離する。

PR plan Role は read-only plan 専用とし、apply / destroy / write 系権限、`iam:PassRole`、S3 lockfile の write/delete 権限を持たせない。

## 背景

PR の Terraform plan は、変更差分を review するための補助であり、apply / destroy を実行する経路ではない。

一方で、`HannibalCICDRole-Dev` は main branch の deploy / destroy 用であり、PR workflow から使うには権限が強い。PR workflow は外部入力を含む可能性があるため、OIDC subject と権限境界を deploy / destroy と分ける必要がある。

## 検討した選択肢

### `HannibalCICDRole-Dev` を PR plan でも使う

- 長所: Role が増えず、実装が単純
- 短所: PR から deploy / destroy 用の強い権限に到達し得る

### PR plan では AWS 認証を行わない

- 長所: AWS 側の権限リスクは最小
- 短所: real state を使った `terraform plan -refresh=true` ができず、レビュー補助として弱い

### PR plan 専用 Role を新設する

- 長所: PR から必要な read-only 権限だけを使える
- 短所: Role / policy / Boundary / workflow の管理対象が増える

## 採択理由

PR plan は review 補助として real state を読む価値があるが、apply / destroy 用 Role を共有する必要はない。

GitHub OIDC subject を `repo:kmryst/terraform-hannibal:pull_request` に限定し、workflow 側でも fork PR を skip する。さらに identity policy と Permission Boundary を read 系に限定することで、PR gate と deploy / destroy 経路の blast radius を分離できる。

## 影響

- PR plan は `HannibalPRPlanRole-Dev` を assume する
- deploy / destroy は `HannibalCICDRole-Dev` を使い続ける
- PR plan Role の変更は IAM / OIDC / Permission Boundary 変更として厳密運用で扱う
- PR plan が失敗しても deploy / destroy Role の問題とは切り分ける

## 関連

- [Issue #121](https://github.com/kmryst/terraform-hannibal/issues/121)
- [Issue #127](https://github.com/kmryst/terraform-hannibal/issues/127)
- [PR #140](https://github.com/kmryst/terraform-hannibal/pull/140)
- [PR Terraform Plan Role Design](../operations/pr-terraform-plan-role-design.md)
- [IAM Management](../operations/iam-management.md)
