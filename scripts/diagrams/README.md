# AWS構成図生成（Diagrams）

## 概要
Diagrams（Python）を使用して NestJS Hannibal 3 の AWS 構成図を手動生成します。

以前は GitHub Actions での自動生成Workflowもありましたが、リポジトリ構成との不整合により廃止しました。
経緯は `docs/architecture/diagram-automation-history.md` を参照してください。

## セットアップ
```powershell
.\setup.ps1
```

## 使用方法
```bash
python generate_aws_diagram.py
```

## 出力先
```
docs/architecture/diagrams/
└── nestjs-hannibal-3-architecture-YYYYMMDD_HHMMSS.png
```

## 対象AWSリソース
- Route53 (hamilcar-hannibal.click)
- CloudFront Distribution
- S3 Static Website
- Application Load Balancer (Blue/Green対応)
- ECS Fargate Service (Blue/Green Deployment)
- ECR Repository
- RDS PostgreSQL
- IAM Roles with Permission Boundary
- CloudWatch Logs
