# AWS構成図自動生成（Diagrams）

## 概要
Diagrams（Python）を使用してNestJS Hannibal 3のAWS構成図を自動生成

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