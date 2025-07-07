# NestJS Hannibal 3 Project Rules

## Infrastructure
- TerraformのstateファイルはS3で管理
- CloudFrontの削除は必ず手動で先に実行
- ECR、S3バケット、OACは事前に手動作成が必要

## Code Style
- TypeScriptの型定義を必須とする
- GraphQLスキーマファーストアプローチを採用
- コメントは日本語で記述

## AWS Resources
- リージョンは ap-northeast-1 を使用
- プロジェクト名プレフィックス: nestjs-hannibal-3
- セキュリティグループは最小権限の原則を適用