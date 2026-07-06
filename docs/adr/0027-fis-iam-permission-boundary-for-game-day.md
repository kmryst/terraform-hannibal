# 0027. Game Day演習向けAWS FIS実行ロールをECSタスク停止のみに限定する

## ステータス

Accepted

## 日付

2026-07-06

## 決定内容

Game Day演習（AWS FISによるECSタスク強制停止で自動復旧を検証する）向けに、`terraform/foundation`で以下を新設する。

- `HannibalFISRole-Dev`: AWS FISが実験実行時にassumeする専用ロール。信頼ポリシーは`fis.amazonaws.com`をprincipalとし、`aws:SourceAccount`（このAWSアカウント）と`aws:SourceArn`（`arn:aws:fis:ap-northeast-1:<account>:experiment/*`、experiment IDはワイルドカード）の両方をconditionに含めてconfused deputy対策とする
- `HannibalFISBoundary-Dev`: `HannibalFISRole-Dev`のPermission Boundary。実権限（`HannibalFISPolicy-Dev`）と同一のstatementsを使い、Boundaryが実権限より広くならないようにする（`HannibalDeveloperBoundary-Dev`と同じパターン）
- 実権限は`ecs:StopTask`を`nestjs-hannibal-3-cluster`のtask ARNのみに限定し、`ecs:DescribeTasks`/`ecs:ListTasks`/`ecs:DescribeClusters`はresource-level権限非対応のためResource `*`とする
- `HannibalCICDBoundary`（`terraform/foundation/iam.tf`の`aws_iam_policy.hannibal_cicd_boundary`）のAllow listに`fis:*`を追加する。これはCICD Roleの最大権限のceilingを広げるのみで、実際にfis権限をCICD Roleの識別ポリシーへ付与するかどうかはGame Day自動化の実装方式が固まる後続Issue（#447）で判断する

## 背景

Issue #446は、Issue #447（AWS FISでECSタスク強制停止によるGame Day演習を自動化する）の前提として、FIS実験がECSタスクを安全に停止できるIAM権限を用意するタスクである。このプロジェクトはIAM変更を`terraform/foundation`で厳密運用として扱い（ADR-0010）、既存のPermission Boundaryパターン（`HannibalDeveloperBoundary-Dev`、`HannibalPRPlanBoundary-Dev`、`HannibalFoundationBoundary-Dev`）はいずれも「実権限と同一のstatementsをBoundaryとしても使う」または「Boundaryは対象サービス範囲だけを大まかに制限する」という設計を踏襲している。

FISは実験テンプレート（`aws_fis_experiment_template`、#447でterraform/serviceまたはterraform/foundationのいずれかに追加予定）が指定するIAM Roleをassumeして、対象リソース（ここではECS task）に対してactionを実行する。AWSの推奨に従い、FISのtrust policyには`aws:SourceAccount`と`aws:SourceArn`の両方を付けてconfused deputyを防ぐ必要があるが、experiment ARNのIDは実験開始時に動的に生成されるため、事前に確定できるのは`experiment/*`というaccount単位のワイルドカードまでである。

## 検討した選択肢

### experiment ARNをワイルドカードにする（採択）

- 長所: `aws:SourceAccount`との組み合わせで、他アカウントやこのアカウント内の他FIS運用からのconfused deputyを実質的に防げる
- 長所: experiment-template作成前（#446時点）でも設計・apply可能で、#447側の実装自由度を保てる
- 短所: 同一アカウント内に将来別のFIS運用（他プロジェクト等）が追加された場合、そちらのexperimentからも本Roleがassumeされ得る。ただしこのAWSアカウントは本プロジェクト専用の想定であり、現実的なリスクは低いと判断する

### experiment-template ARNを先に固定IDで作成し、それを条件にする

- 長所: より厳密なconfused deputy対策になる
- 短所: `aws_fis_experiment_template`は#447で作成する予定であり、#446の時点でリソースを前倒しで作ると、Issue分割の境界（IAM/Permission Boundary整備とFIS実験テンプレート設計を分ける）が崩れる
- 短所: experiment templateのIDはTerraformが生成するため、`aws:SourceArn`にテンプレートIDを条件指定してもtrust policy自体は実質的にテンプレートIDでなくexperiment IDで評価される（FISのtrust conditionはexperiment ARNであり、experiment-template ARNではない）ため、この選択肢は技術的に成立しない

### `HannibalCICDRole-Dev`にfis権限を直接付与する

- 長所: #447の実装が早く進む
- 短所: #446の受け入れ条件は「CICD用Boundaryに`fis:*`を含む必要最小限の権限が追加されている」であり、実権限の付与ではなくceilingの拡張が対象。実権限は#447でGame Day自動化の実装方式（GitHub Actionsから直接fis APIを呼ぶか、別Roleを使うか）が決まってから最小権限で設計する方が、余分な権限を早期に持たせずに済む

## 採択理由

`HannibalFISRole-Dev`をECSタスク停止のみに限定したPermission Boundary付きロールとして新設することで、万が一FIS実験テンプレートの設定に誤りがあっても、実際に実行できる操作はECS taskの停止に限定される。これはGame Day演習の目的（ECSタスク強制停止による自動復旧検証）そのものであり、過不足のない権限設計になる。

`HannibalCICDBoundary`への`fis:*`追加は、既存の`ec2:*`、`ecs:*`等と同じ「ceilingとしてサービス単位のwildcardを許可する」パターンに従う。実権限の追加を#447に委ねることで、Game Day自動化の実装方式が確定してから必要最小限のfis権限（`fis:StartExperiment`、`fis:GetExperiment`等）を設計でき、未使用のまま広い権限を持たせるリスクを避けられる。

## 影響

- `terraform/foundation/iam.tf`: `HannibalFISRole-Dev`、`HannibalFISBoundary-Dev`、`HannibalFISPolicy-Dev`を新設。`aws_iam_policy.hannibal_cicd_boundary`に`fis:*`のAllow statementを追加
- `docs/operations/iam-management.md`: Roleカタログと構成図を更新
- 新規AWSリソースのコスト影響はなし（IAM RoleとPolicyは無料）
- foundationへの実際の`terraform apply`は人間が手動実行する（既存運用方針どおり、`state rm`はしない）
- 後続Issue #447で実験テンプレートを作成する際は、`role_arn`に`HannibalFISRole-Dev`のARNを指定する

**追記（2026-07-06、Issue #454）**: #447で実際に`aws_fis_experiment_template`をterraform/serviceからapplyしたところ、`HannibalCICDRole-Dev`の識別ポリシーにfis権限が一切ないため`fis:CreateExperimentTemplate`でAccessDeniedになることが判明した。本ADRで「実権限の付与は#447で判断する」としていたが、実際に必要になったのはterraform applyを実行するCICD Role自身への権限付与であり、Issue #454で`HannibalCICDPolicy-Dev-deploy`にexperiment-templateリソースへ限定した`fis:*`系操作と`HannibalFISRole-Dev`への`iam:PassRole`（`PassedToService=fis.amazonaws.com`条件）を追加して解消した。

## 関連

- [Issue #446](https://github.com/kmryst/terraform-hannibal/issues/446)
- [Issue #447](https://github.com/kmryst/terraform-hannibal/issues/447)
- [IAM権限管理](../operations/iam-management.md)
- [ADR 0010: 軽運用 / 厳密運用を分ける GitHub Flow モデルを採用する](./0010-adopt-lightweight-and-strict-github-flow.md)
