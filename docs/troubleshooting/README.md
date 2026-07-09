# トラブルシューティング事例

## 1. CodeDeploy Blue/Green デプロイ設定

**課題**: ECS Blue/Greenデプロイメントの実装

**対応内容**:
- ターゲットグループの順序を正しく設定（Blue → Green）
- CodeDeployに必要なIAM権限を段階的に追加（PassRole、ECS操作権限）
- ヘルスチェックパスを `/health` に統一

**成果**: 安定したBlue/Greenデプロイメントを実現し、5分以内の無停止切替を達成

**学び**: AWS公式ドキュメントとTerraformプロバイダーの仕様差異を理解し、段階的なデバッグの重要性を認識

## 2. IAM Permission Boundary による最小権限設計

**課題**: セキュリティを保ちながらCI/CDパイプラインに必要な権限を付与

**対応内容**:
- Permission Boundaryで権限の上限を設定
- 必要な権限を段階的に追加（DynamoDB、CodeDeploy、ECS等）
- CloudTrailで権限使用状況を監視

**成果**: 最小権限の原則を実装しながら、完全自動化されたCI/CDを実現

**学び**: セキュリティと利便性のバランスを取る設計の重要性

## 3. Terraform リソース削除順序の最適化

**課題**: `terraform destroy` 時のTarget Group削除エラー

**対応内容**:
- リソース間の依存関係を分析
- destroy.ymlで削除順序を制御（CloudFront → ALB → ECS → RDS）
- 各モジュールの削除を段階的に実行

**成果**: クリーンな環境削除を実現し、コスト管理を効率化

**学び**: IaCにおけるリソース依存関係の理解と、適切な削除戦略の重要性

## 4. 三層VPC アーキテクチャへの移行

**課題**: デフォルトVPCから本番レベルの3層VPC（Public/App/Data）への移行

**対応内容**:
- Private SubnetのECSタスクにNATゲートウェイ経由のインターネットアクセスを設定
- ルートテーブルを適切に構成（App → NAT、Data → ローカルのみ）
- セキュリティグループで最小権限通信を実装

**成果**: セキュアなネットワーク設計を実現し、DB層を完全に外部非公開化

**学び**: エンタープライズレベルのネットワーク設計とセキュリティベストプラクティス

## 5. Terraform State 管理の自動化

**課題**: State Lockによる並行実行制御

**対応内容**:
- S3 backend + S3 lockfileでState管理を実装
- State Lockの仕組みを理解し、異常終了時の対処方法を確立
- GitHub Actionsで排他制御を実装

**成果**: 安全な並行実行制御と、チーム開発に対応可能な基盤を構築

**学び**: IaCにおける状態管理の重要性と、チーム開発を見据えた設計

## 6. PR Policy Check の pending run が cancel され required check がブロックされる問題

**課題**: PR 作成 helper がラベル（type/area/risk/cost）を連続付与すると `pull_request` の `labeled` イベントが短時間に連発し、`pr-policy-check.yml` の required status check が一時的に `expected`（未充足）扱いになりマージがブロックされる

**対応内容**:
- 根本原因を GitHub Actions の concurrency デフォルト挙動（`queue: single`）と特定。`queue: single` は pending run を 1 つしか保持せず、`labeled`/`unlabeled` 連発時に古い pending run が cancel され、その CANCELLED check run が required status check 判定に混入する（先行課題 Issue #438 の CANCELLED check ブロックと同根の挙動）
- `pr-policy-check.yml` の `concurrency` に `queue: max` を追加（Issue #485 / PR #486）。pending run を cancel せず FIFO で順次実行させる。`queue: max` は `cancel-in-progress: false` と併用可能（`cancel-in-progress: true` との併用のみ validation error）
- ラベル判定は `gh pr view` で最新ラベルを都度再取得しているため、古い payload の run が後から実行されても判定結果は変わらない
- `cancel-in-progress: true` を使う `pr-check.yml`（重い CI。新 SHA で安全に上書きできる）には `queue: max` を追加しない

**成果**: idp-golden-path / terraform-hannibal / ticket-c2c-platform の 3 リポジトリ同一構成に横展開し、ラベルを 11 回連続で付け外しする実地検証（3 リポジトリ合計 47 run）で CANCELLED 0 件を確認。required check の一時 `expected` 化が解消

**学び**: required status check の判定は同名 check run の履歴全体を評価対象にするため、concurrency による run の cancel が「軽量ジョブでも」マージブロックの原因になり得る。concurrency は `cancel-in-progress` だけでなく `queue` の挙動まで含めて、ジョブが冪等か（古い run を捨ててよいか）で選ぶ
