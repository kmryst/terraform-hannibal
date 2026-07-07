# Roadmap（検討中の実装候補メモ）

このファイルは ADR（確定した設計判断）でも、着手対象として起票済みの Issue でもない。
「まだ Issue化するほど固まっていないが、実装するとポートフォリオとしての価値が上がりそうな候補」を優先順位付きで記録する場所とする。

- 項目が育って着手可能になったら、該当する Issue 番号をこのファイルに追記する。
- Issue/ADR の open/closed 状態はリンク先の実態を正とする。このファイル内の記述が古くなったら都度修正する。
- 起票・実装時は通常どおり `CLAUDE.md` / `CONTRIBUTING.md` の Issue 駆動フローに従う。

## 背景

2026-07-06、ユーザーと「次に実装するとDevOps/SRE/Platform Engineeringのポートフォリオ価値が上がるものは何か」を検討し、4案を作成した。その後 Fable（サブエージェント）にリポジトリの実態検証込みでレビューを依頼したところ、複数の前提誤りが見つかったため、レビュー結果を反映して優先順位を修正した。

## 優先順位

### 1. SLO運用のフレーミング修正（burn rateアラートへの接続）【対応済み】

**対応済み**: Issue [#445](https://github.com/kmryst/terraform-hannibal/issues/445) / PR [#449](https://github.com/kmryst/terraform-hannibal/pull/449) / [ADR-0026](./adr/0026-slo-burn-rate-alerts-for-alb-slis.md) でALB系SLI（エラー率・応答時間）のmetric math算出とmulti-window multi-burn-rateアラームを実装済み。後続で稼働率SLIもCloudWatch Synthetics canaryのtime-based availabilityとしてアラームに接続した（[ADR-0030](./adr/0030-adopt-cloudwatch-synthetics-canary-for-user-journey-monitoring.md)、Issue [#467](https://github.com/kmryst/terraform-hannibal/issues/467) / PR [#468](https://github.com/kmryst/terraform-hannibal/pull/468)）。

[`docs/operations/slo.md`](./operations/slo.md) に SLI/SLO/エラーバジェット運用は既に文書化済み（旧 Issue #274、クローズ済み）。当時の課題は「文書はあるが、計測とアラートがSLOに接続されていない」ことだった。

- `terraform/modules/monitoring/` の静的閾値アラーム（CPU高い、5xx多い等）を、multi-window multi-burn-rateアラートに組み替える
- 応答時間・エラー率のSLIをmetric mathで計算し、`slo.md`のSLO目標値（月次可用性99.5%等）と接続する
- **設計判断（ADR級）**: 通常destroy済み・低トラフィック運用（ADR-0008）では、リクエスト数が少なくratioベースSLIが統計的に暴れる（1リクエスト失敗で瞬間エラー率100%になる等）。最小リクエスト数ガードや、Syntheticsで分母を作る等の対処をどう設計するかが独自の判断ポイントになる
- 「文書化されたSLO」から「計測可能なSLO」への昇格として新規Issue起票が必要（#274は別件のため再利用しない）

### 2. Terraform継続検証基盤（drift検出 + #410の統合）

単純な「5 root moduleへの定期plan」は、dev環境が平常時destroy済み（ADR-0008）の運用と矛盾する。state不在・上流output不在でplanがexit 1になり、[Issue #410](https://github.com/kmryst/terraform-hannibal/issues/410)（destroy済み環境で意味のあるPR Terraform Planを再設計する）が既に同じ壁にぶつかっている。

- 単体のdrift検出パイプラインとして立てるのではなく、#410の根本対応と統合した「destroy済み運用と両立するTerraform継続検証基盤」として再設計する
- `docs/operations/terraform-runbook.md` のcomposite root module案（L119付近）が設計の下地になる
- 恒久リソースである `terraform/foundation/` は常設のため、まずここだけ定期drift検出を先行導入する選択肢もある

### 3. Game Day演習の自動化【対応済み】

**対応済み**: Issue [#446](https://github.com/kmryst/terraform-hannibal/issues/446) / [#447](https://github.com/kmryst/terraform-hannibal/issues/447) / [#458](https://github.com/kmryst/terraform-hannibal/issues/458) / [#461](https://github.com/kmryst/terraform-hannibal/issues/461)、PR [#450](https://github.com/kmryst/terraform-hannibal/pull/450) / [#451](https://github.com/kmryst/terraform-hannibal/pull/451) / [#459](https://github.com/kmryst/terraform-hannibal/pull/459) / [#462](https://github.com/kmryst/terraform-hannibal/pull/462)、[ADR-0027](./adr/0027-fis-iam-permission-boundary-for-game-day.md) / [ADR-0028](./adr/0028-fis-game-day-ecs-task-stop-experiment-design.md) / [ADR-0029](./adr/0029-separate-fis-observability-root-module-for-blast-radius.md) で実装済み。AWS FISによるECSタスク強制停止演習（`scripts/game-day/run-ecs-task-stop-experiment.sh`）、演習記録テンプレート、blast radius分離（`terraform/observability`）まで含む。

ECSタスクを意図的にkillしてCodeDeployの自動復旧・アラーム発火・runbookの実効性を検証する演習をスクリプト化する。

- 既存資産（`docs/operations/runbook.md`、CodeDeploy Blue/Green自動ロールバック、`ecs-task-stopped`アラーム）と最も噛み合う
- 通常destroy済み運用はここでは弱点でなく強みになる。「deploy → Game Day実施 → 結果記録 → destroy」という演習サイクルとして設計・文書化でき、コストは演習時間分のみ
- AWS FIS（ECSタスク停止アクション）を使えばTerraform実装対象にもなる
- 案1（SLO/burn rate）の検証手段を兼ねるため、案1の後に実施すると相互に価値が高まる

### 4. root module単位のIAM最小権限設計

ADR-0020の「影響」節で「IAM RoleのResource scopeがroot moduleごとに異なる可能性、Issue #392再設計時に検討する」と記載されているが、#392は既にクローズ済み（内容もSupersededになったPR Preview Environmentの設計で別件）。課題自体は実在するが、現状どのIssueにも紐づいていない。

- 着手するならまず追跡Issueの起票から
- 既存のIAM構成（Role 5種のカタログ、全RoleにPermission Boundary、policy 3分割、ADR-0006/iam-management.mdでの文書化）は既にポートフォリオとして十分厚く、単一workflowが4 moduleを順に実行する現構成でRoleを分割しても複雑さが増えるだけになりうる
- 「複数人運用の前提を整える」という動機は、現状1人運用のポートフォリオでは説得力が弱いため、優先度は最下位とする

## 関連（既存のOpen Issue）

上記の候補とは別に、以下がGitHub上でOpenになっている。

- [#186](https://github.com/kmryst/terraform-hannibal/issues/186) コスト超過時に destroy.yml を自動トリガーする仕組みを実装する（risk:high）— Budgets→自動destroyのFinOpsガードレール。destroy済み運用の物語と一貫しており、4案と並べて検討する価値がある
- [#282](https://github.com/kmryst/terraform-hannibal/issues/282) backend・frontendのユニットテストを拡充しrequired化の判断材料を作る
- [#349](https://github.com/kmryst/terraform-hannibal/issues/349) RDS FreeableMemory / CPUCreditBalance アラームを追加
- [#378](https://github.com/kmryst/terraform-hannibal/issues/378) ロールバック時のRDS管理シークレットARN不整合を解消する
- [#380](https://github.com/kmryst/terraform-hannibal/issues/380) ALBリスナーのdefault_actionとECS PRIMARY tasksetの不一致でCodeDeployデプロイが失敗する
- [#383](https://github.com/kmryst/terraform-hannibal/issues/383) ECSロールバック候補の継続的な起動可能性チェックを追加する

## 見送り・優先度を下げた判断

- **分散トレーシング（X-Ray/OpenTelemetry）**: 現構成は Client → CloudFront → ALB → ECS（単一NestJSサービス） → RDS で、自分のアプリ層はサービス1つのみ。分散トレーシング本来の価値（複数の独立したサービスをまたぐ因果関係の可視化）が発揮しにくいため、優先度を下げる。将来サービスを分割するタイミングで再検討する。
