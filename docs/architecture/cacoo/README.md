# AWS Architecture Diagram

## 全画面表示

<div align="center">
  <img src="architecture.svg" alt="AWS Architecture Diagram" width="100%">
</div>

## 構成要素

- **Route53**: DNS管理
- **CloudFront**: CDN配信
- **S3**: 静的ファイルホスティング
- **ALB**: ロードバランサー
- **ECS Fargate**: コンテナ実行環境
- **RDS**: PostgreSQLデータベース
- **IAM**: 権限管理
- **CloudWatch**: 監視・ログ

## アクセス方法

1. [Raw SVGファイル](https://raw.githubusercontent.com/kmryst/terraform-hannibal/feature/automation/docs/architecture/cacoo/architecture.svg)で全画面表示
2. ブラウザの拡大機能（Ctrl + マウスホイール）で詳細確認