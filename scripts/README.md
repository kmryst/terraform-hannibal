# Scripts

運用・開発支援スクリプト集

## 📁 ディレクトリ構成

### monitoring/
- **blue-green-monitor.ps1** - Blue/Green Deployment監視スクリプト
- **README.md** - 監視スクリプトの使用方法

### deployment/
- **deploy-codedeploy.ps1** - CodeDeploy Blue/Greenデプロイメントスクリプト

### github/
- **create-issue-with-labels.sh** - 必須4ラベル付きで Issue を作成するヘルパー
- **create-pr-with-labels.sh** - 必須4ラベル付きで PR を作成するヘルパー

### game-day/
- **run-ecs-task-stop-experiment.sh** - AWS FISでECSタスクを強制停止するGame Day演習実行スクリプト（`destroy.yml`は自動トリガーしない）。記録テンプレートは[game-day-exercise-template.md](../docs/operations/game-day-exercise-template.md)、手順は[runbook.md](../docs/operations/runbook.md)のGame Day演習節を参照

## 🚀 今後の拡張予定

### setup/
- 環境セットアップスクリプト
- 依存関係インストールスクリプト

### maintenance/
- ログクリーンアップスクリプト
- データベースメンテナンススクリプト

## 📋 使用方法

各ディレクトリのREADMEを参照してください。

GitHub 運用用スクリプトの使い方は [CONTRIBUTING.md](../CONTRIBUTING.md) を参照してください。

## 🔐 権限要件

スクリプト実行には適切なAWS IAM権限が必要です。詳細は[運用ガイド](../docs/operations/README.md)を参照してください。
