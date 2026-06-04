# Threat Model

この文書は `terraform-hannibal` の Terraform / AWS / GitHub Actions 基盤に対する脅威モデルです。
目的は、まだ発生していないインシデントを先回りして想定し、既存の対策、残存リスク、再検討条件を DevOps / SRE / Platform Engineering の観点で説明できるようにすることです。

セキュリティ実装の一覧は [Security Design](../architecture/security-design.md)、IAM Role の正本は [IAM権限管理](../operations/iam-management.md)、Terraform 操作手順は [Terraform Runbook](../operations/terraform-runbook.md) を参照します。

## 前提

- 現在の実稼働対象は `dev` 環境のみです。
- `dev` はポートフォリオ / デモ用途で、通常は destroy 済みの停止運用とします。
- デモ時だけ deploy し、確認後に destroy するため、常時公開サービスと同じ脅威検知・防御コストはかけません。
- 本番相当の共有環境、継続公開、外部利用者増加が発生した場合は、本脅威モデルを見直します。
- Terraform state、GitHub Actions OIDC、IAM Role、Secrets Manager、RDS、CloudTrail / Athena を主な保護対象とします。

## 保護対象

| 資産 | 重要性 | 主なリスク |
|---|---|---|
| Terraform state bucket | インフラ構成、resource ARN、生成 secret 相当値を含み得る | state 漏洩、誤更新、lock 競合 |
| GitHub repository / PR | IaC と workflow の変更入口 | 不正な workflow 変更、secret 混入、review bypass |
| GitHub Actions OIDC | AWS Role を assume する認証経路 | PR からの強権限 Role 悪用、main workflow の誤実行 |
| IAM Role / Permission Boundary | AWS 操作権限の境界 | 過剰権限、横移動、権限昇格 |
| Secrets Manager / RDS | アプリケーションデータと DB 認証情報 | 認証情報漏洩、DB 侵害、データ消失 |
| CloudFront / ALB / ECS | 外部公開面と実行基盤 | 直アクセス、脆弱性悪用、DoS |
| CloudTrail / Athena | 監査と権限見直しの根拠 | 監査ログ欠落、検知遅延 |

## 信頼境界

| 境界 | 信頼する側 | 信頼しない入力 |
|---|---|---|
| Pull Request -> PR Check | repository 内の CI 定義、required status checks | PR 差分、Terraform / app code、外部 action の実行結果 |
| GitHub Actions -> AWS OIDC | GitHub OIDC token、trust policy、workflow 条件 | PR head code、workflow 改変案 |
| Terraform -> AWS control plane | Assume 済み Role、Terraform provider | state、variables、plan で評価される IaC |
| CloudFront / ALB -> ECS | CloudFront origin-facing traffic、origin verify header、security group | インターネットからの任意 HTTP request |
| ECS -> RDS / Secrets Manager | ECS task execution role、private subnet、security group | アプリケーション入力、侵害済み container |
| Operator laptop -> GitHub / AWS | `gh` / AWS CLI の認証済み操作 | ローカル credential 漏洩、誤操作 |

## 脅威シナリオ

| ID | 脅威 | 影響 | 現状の対策 | 残存リスク / 対応 |
|---|---|---|---|---|
| T1 | Terraform state 漏洩 | resource ARN、構成値、Terraform 生成 secret 相当値が漏れる。ALB origin verify header など state 内の値は Git に無くても漏洩対象になる | state は S3 backend に集約し、操作 Role を分離。foundation state は `HannibalFoundationRole-Dev`、dev state は用途別 Role で扱う。S3 lockfile を正とし、Runbook で lock 手順を管理 | `HannibalPRPlanRole-Dev` は read-only でも dev state を読むため、state 参照は無害ではない。CloudTrail は management events 中心のため、S3 object-level read の可視性は限定的。漏洩時は確認可能な Role assume / IAM / bucket policy / workflow 実行履歴を追い、origin verify header、DB credential、関連 secret をローテーションする |
| T2 | CI 経由の不正 apply / destroy | PR や workflow 改変から AWS resource を作成・変更・削除される | deploy / destroy は `main` の GitHub OIDC subject に限定した `HannibalCICDRole-Dev` を使う。PR plan は別 Role。`main` は PR 必須、required checks、commitlint、PR policy check で保護する。destroy は `workflow_dispatch` と `DESTROY` 入力を要求する | `main` に入った workflow 変更は強い影響を持つ。workflow / IAM / deploy / destroy 変更は厳密運用で扱い、異常時は workflow 無効化、OIDC trust policy 変更、CICD Role policy rollback を行う |
| T3 | PR Terraform plan Role 悪用 | PR から AWS の read API と dev state を参照され、構成情報が漏れる | `HannibalPRPlanRole-Dev` は PR plan 専用。`pull_request` subject に限定し、fork PR は workflow 側で skip。`pull_request_target` で PR head を実行しない。apply / destroy / write 系、`iam:PassRole`、S3 lockfile write/delete、`secretsmanager:GetSecretValue` を付与しない。専用 Permission Boundary で最大権限も read 系に制限 | read-only でも情報漏洩リスクは残る。plan log / artifact に機微情報を出さない。不要な data source や output を増やす変更は PR で確認する |
| T4 | IAM 過剰権限による横移動 | 1つの Role 侵害から IAM / OIDC / state / deploy 権限へ拡大される | Developer / Foundation / CICD / PRPlan Role を分離。write / exec は action 列挙と Resource scope を基本にする。Hannibal 系 Role には Permission Boundary を設定し、Foundation Role も自分自身の Boundary を更新しない | read 系 wildcard は運用性のため一部採用している。CloudTrail / Athena で使用実績を見て段階的に縮小する。権限追加は厳密運用で扱う |
| T5 | secret / credential の Git 混入 | Git history から token、password、private key が漏れる | GitHub Actions は AWS 長期 access key ではなく OIDC を使う。DB 認証情報は Secrets Manager / RDS managed secret で扱う。Gitleaks Secret Scan は required status check として PR を止める | Terraform state や CI log に secret 相当値が残る可能性は Gitleaks だけでは防げない。コマンド出力共有時は credential 値を貼らず、漏洩時は secret rotation と Git history 対応を行う |
| T6 | CloudFront / ALB 直アクセス、L7 攻撃 | ALB 直接到達、bot traffic、脆弱 endpoint への試行で可用性やアプリ層が影響を受ける | ALB security group は CloudFront origin-facing prefix list からの ingress に限定。CloudFront origin custom header `X-Hannibal-Origin-Verify` と ALB listener rule で二段制限。ECS は private subnet、RDS は private subnet で外部非公開 | WAF は有効化していないため、L7 filtering は限定的。短時間公開・通常 destroy 済みの accepted risk とする。攻撃的 traffic、4xx / 5xx 増加、継続公開へ移行した場合は CloudFront Web ACL を優先して再検討する |
| T7 | ECS / アプリケーション侵害から DB へ到達 | コンテナ脆弱性や GraphQL 入力不備を経由して RDS データが読まれる / 壊される | ECS task は private subnet で動作し、RDS ingress は ECS security group からの 5432 のみに限定。コンテナは non-root user で実行。GraphQL playground / introspection は production で無効化し、class-validator による入力検証を行う | 認証・認可は将来実装であり、アプリ層の権限分離は弱い。外部利用者が増える、実データを扱う、本番相当環境にする場合は認証・認可、rate limit、WAF を再検討する |
| T8 | 監査・検知の遅延 | 不正操作に気付くまで時間がかかり、原因追跡が遅れる | CloudTrail を有効化し、CloudTrail log を S3 に保存。Athena で IAM 使用状況を分析する。CloudWatch Alarm / Dashboard で ECS、ALB、RDS、Billing を監視する | GuardDuty はコスト最適化のため停止中。リアルタイム脅威検知は弱い。継続公開、本番相当化、攻撃兆候の観測時は GuardDuty 有効化を再検討する |
| T9 | destructive workflow / 誤 destroy | dev 環境の意図しない削除、デモ中の停止、復旧時間の発生 | destroy は `main` の OIDC Role でのみ実行し、`workflow_dispatch` と明示的な `DESTROY` 入力を要求する。dev は通常 destroy 済みで、SLO でも計画的 destroy / deploy を対象外とする。Rollback Plan と Terraform Runbook を用意する | dev availability は意図的に低コスト運用へ寄せている。共有環境や本番相当環境では同じ destroy 運用を採用しない |
| T10 | supply chain / GitHub Action 依存の侵害 | 外部 action や依存更新を経由して CI 上で不正コードが実行される | 公式 action は major tag で管理し、Dependabot で更新を追跡する。PR gate で build / test / scan を実行する。重い security scan は週次 / 手動 workflow に分離する | SHA pin は現時点では採用していない。外部 action のメンテ停止や改ざんリスクが高まった場合は、公式 action への置換、`actions/github-script` / `gh` による自前化、SHA pin を検討する |

## Accepted Risk

| 項目 | 現在の判断 | 理由 | 再検討条件 |
|---|---|---|---|
| WAF 無効化 | accepted risk | デモ用途、短時間公開、通常 destroy 済み運用のため、常時 WAF の固定費に対する効果が限定的 | 継続公開、外部利用者増加、攻撃的 traffic、bot、異常な 4xx / 5xx 増加 |
| GuardDuty 停止 | accepted risk | ポートフォリオ用途では月額コストを優先し、CloudTrail / Athena による事後分析を採用 | 本番相当化、共有環境化、AWS account の重要度上昇、脅威兆候の観測 |
| Trivy Config の review signal 扱い | accepted risk | WAF / KMS / CMK など、コスト最適化や意図的な設計判断も finding になるため、blocking gate 前に棚卸しが必要 | finding を修正対象 / accepted risk / ignore に分類できた後、`exit-code: 1` への変更を検討 |
| PR plan の state read | accepted risk | 実 state を使う plan はレビュー価値が高く、destroy 済み dev 環境の再構築予行演習として有効 | state 内の secret 相当値が増える、PR 実行者が増える、fork / 外部 contributor を本格受け入れする |
| S3 object-level state read 監査の限定性 | accepted risk | 現在の CloudTrail は management events を主対象にし、IAM / OIDC / workflow / policy 変更の検知を優先している | state access の精密な追跡が必要になった場合、state bucket の S3 data events 有効化とコストを検討する |
| dev の destroy 運用 | accepted risk | コスト最適化を優先し、必要時だけ起動する前提 | 常時利用者がいる、RTO / SLO が必要になる、本番相当環境へ移行する |

## 運用時の確認ポイント

PR review では、次の変更を通常の docs / app 変更より強く確認します。

- `.github/workflows/**` の OIDC、permissions、event、artifact、log 出力の変更
- `terraform/foundation/**` の IAM / OIDC / Permission Boundary / CloudTrail / Athena / Budgets 変更
- `terraform/environments/**` の state backend、Secrets Manager、RDS、security group、CloudFront / ALB 変更
- Terraform output、GitHub Actions log、Job Summary に secret 相当値を出す変更
- `HannibalPRPlanRole-Dev` の read 範囲拡大、`HannibalCICDRole-Dev` の write / destroy 範囲拡大

運用監査では、次を定期的に確認します。

- CloudTrail / Athena による IAM action 使用状況
- PR Check の Gitleaks / TFLint / Trivy Config の結果
- CloudWatch Alarm、ALB 4xx / 5xx、ECS task health、RDS connection
- GitHub Actions の deploy / destroy / pr-check 実行履歴
- Dependabot PR と GitHub Security alerts

## インシデント時の初動

| 兆候 | 初動 |
|---|---|
| state 漏洩疑い | GitHub Actions 実行履歴、OIDC assume、IAM / bucket policy 変更、確認可能な state bucket 操作履歴を調べる。S3 object-level read は現構成では可視性が限定的なため、漏洩可能性がある値は origin verify header、DB credential、関連 secret を優先してローテーションする |
| 不審な GitHub Actions 実行 | workflow を無効化し、対象 run の actor、commit、OIDC assume 先 Role を確認する。必要なら IAM trust policy を一時的に絞る |
| PRPlanRole の過剰な情報露出 | plan log / artifact / output を確認し、漏洩した値を rotation 対象にする。Role policy と Terraform output を見直す |
| 不審な AWS API 呼び出し | CloudTrail / Athena で principal、source IP、eventName、userAgent を確認する。対象 Role の policy / trust policy を一時的に縮小する |
| 外部公開面への攻撃的 traffic | CloudWatch / ALB metrics / CloudFront logs を確認し、必要に応じて環境 destroy、CloudFront Web ACL 導入、origin header rotation を検討する |
| secret 混入 | Gitleaks finding を確認し、該当 secret を即時 revoke / rotate する。Git history 対応が必要な場合は別途厳密運用で扱う |

## 見直し条件

次のいずれかに当てはまる場合、この脅威モデルと [Security Design](../architecture/security-design.md) を更新します。

- dev 以外の staging / prod 環境を追加する
- 継続公開または外部ユーザー向け運用へ移行する
- 認証・認可を実装し、実ユーザーデータを扱う
- WAF / GuardDuty / KMS CMK / CloudFront private origin などの security control を追加する
- IAM Role、OIDC trust policy、Permission Boundary、state backend の設計を変更する
- 実インシデント、near miss、CI / AWS の異常操作を観測する
