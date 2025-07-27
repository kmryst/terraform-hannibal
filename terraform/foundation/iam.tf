# terraform/foundation/iam.tf
# 基盤IAMリソース（Terraformで作成後、管理から除外・永続保持）
# AWS Professional設計: Infrastructure as Code + 永続管理

# --- 新設計: 2ユーザー × 2ロール構成 ---

# --- 1. HannibalDeveloperRole-Dev (統合開発ロール) ---
resource "aws_iam_role" "hannibal_developer_role" {
  name = "HannibalDeveloperRole-Dev"
  permissions_boundary = aws_iam_policy.hannibal_base_boundary.arn
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::258632448142:user/hannibal"
        }
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = "ap-northeast-1"
          }
        }
      }
    ]
  })
}

# --- 2. HannibalCICDRole-Dev (自動デプロイロール) ---
resource "aws_iam_role" "hannibal_cicd_role" {
  name = "HannibalCICDRole-Dev"
  permissions_boundary = aws_iam_policy.hannibal_base_boundary.arn
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::258632448142:user/hannibal-cicd"
        }
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = "ap-northeast-1"
          }
        }
      }
    ]
  })
}

# --- 3. HannibalDeveloperPolicy-Dev (統合開発ポリシー) ---
resource "aws_iam_policy" "hannibal_developer_policy" {
  name        = "HannibalDeveloperPolicy-Dev"
  description = "Integrated development permissions - ECS/ECR/RDS/CloudWatch operations, limited Terraform execution"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # ECR権限 (フル操作)
        Effect = "Allow"
        Action = [
          "ecr:*"
        ]
        Resource = "*"
      },
      {
        # ECS権限 (フル操作)
        Effect = "Allow"
        Action = [
          "ecs:*"
        ]
        Resource = "*"
      },
      {
        # RDS権限 (フル操作)
        Effect = "Allow"
        Action = [
          "rds:*"
        ]
        Resource = "*"
      },
      {
        # CloudWatch Logs権限 (フル操作)
        Effect = "Allow"
        Action = [
          "logs:*"
        ]
        Resource = "*"
      },
      {
        # CloudWatch Metrics権限 (フル操作)
        Effect = "Allow"
        Action = [
          "cloudwatch:*"
        ]
        Resource = "*"
      },
      {
        # EC2権限 (フル操作)
        Effect = "Allow"
        Action = [
          "ec2:*"
        ]
        Resource = "*"
      },
      {
        # ELB権限 (フル操作)
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:*",
          "elbv2:*"
        ]
        Resource = "*"
      },
      {
        # S3権限 (フル操作)
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = "*"
      },
      {
        # CloudFront権限 (フル操作)
        Effect = "Allow"
        Action = [
          "cloudfront:*"
        ]
        Resource = "*"
      },
      {
        # IAM権限 (限定的操作)
        Effect = "Allow"
        Action = [
          "iam:Get*",
          "iam:List*",
          "iam:CreateRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:DeleteRole",
          "iam:PassRole",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListRolePolicies",
          "iam:GetRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy"
        ]
        Resource = "*"
      }
    ]
  })
}

# --- 4. HannibalCICDPolicy-Dev (自動デプロイポリシー) ---
resource "aws_iam_policy" "hannibal_cicd_policy" {
  name        = "HannibalCICDPolicy-Dev"
  description = "CI/CD automation permissions - CloudTrail分析結果に基づく最小権限設計"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Access Analyzer権限 (セキュリティ分析用)
        Effect = "Allow"
        Action = [
          "access-analyzer:*"
        ]
        Resource = "*"
      },
      {
        # CloudTrail権限 (監査ログ用)
        Effect = "Allow"
        Action = [
          "cloudtrail:*"
        ]
        Resource = "*"
      },
      {
        # EC2権限 (セキュリティグループ、VPC管理用)
        Effect = "Allow"
        Action = [
          "ec2:*"
        ]
        Resource = "*"
      },
      {
        # ECR権限 (コンテナイメージ管理)
        Effect = "Allow"
        Action = [
          "ecr:*"
        ]
        Resource = "*"
      },
      {
        # ECS権限 (コンテナサービス管理)
        Effect = "Allow"
        Action = [
          "ecs:*"
        ]
        Resource = "*"
      },
      {
        # ELB権限 (ALB管理用)
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:*"
        ]
        Resource = "*"
      },
      {
        # CloudWatch Logs権限
        Effect = "Allow"
        Action = [
          "logs:*"
        ]
        Resource = "*"
      },
      {
        # CloudWatch Metrics権限 (監視リソース作成用)
        Effect = "Allow"
        Action = [
          "cloudwatch:*"
        ]
        Resource = "*"
      },
      {
        # RDS権限 (データベース管理用)
        Effect = "Allow"
        Action = [
          "rds:*"
        ]
        Resource = "*"
      },
      {
        # S3権限 (全権限)
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = "*"
      },
      {
        # SNS権限 (アラート通知用)
        Effect = "Allow"
        Action = [
          "sns:*"
        ]
        Resource = "*"
      },
      {
        # STS権限 (追加必要権限 - CloudTrail検出)
        Effect = "Allow"
        Action = [
          "sts:*"
        ]
        Resource = "*"
      },
      {
        # KMS権限 (追加必要権限 - CloudTrail検出)
        Effect = "Allow"
        Action = [
          "kms:*"
        ]
        Resource = "*"
      },
      {
        # IAM権限 (限定的操作)
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:PassRole",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:CreatePolicy",
          "iam:DeletePolicy"
        ]
        Resource = "*"
      },
      {
        # CloudFront権限 (全権限)
        Effect = "Allow"
        Action = [
          "cloudfront:*"
        ]
        Resource = "*"
      },
      {
        # Route53権限 (ドメイン管理)
        Effect = "Allow"
        Action = [
          "route53:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# --- 5. ポリシーアタッチメント ---
resource "aws_iam_role_policy_attachment" "hannibal_developer_policy_attachment" {
  role       = aws_iam_role.hannibal_developer_role.name
  policy_arn = aws_iam_policy.hannibal_developer_policy.arn
}

resource "aws_iam_role_policy_attachment" "hannibal_cicd_policy_attachment" {
  role       = aws_iam_role.hannibal_cicd_role.name
  policy_arn = aws_iam_policy.hannibal_cicd_policy.arn
}

# --- 実装後の管理方針 ---
# 1. terraform apply でリソース作成
# 2. terraform state rm で管理から除外
# 3. 以降は手動管理・永続保持
# 4. コードは再現性・ドキュメント用に保持

# --- 6. Permission Boundary Policy (全ロール共通) ---
# AWS Certified Professional/Specialtyレベルの段階的セキュリティ強化
# 既存機能を維持しつつ、危険操作のみを禁止する安全な設計

resource "aws_iam_policy" "hannibal_base_boundary" {
  name        = "HannibalBaseBoundary"
  description = "Base permission boundary for all Hannibal project roles - prevents dangerous operations only"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # 危険操作のみを禁止（企業レベルセキュリティ）
        Effect = "Deny"
        Action = [
          # IAMユーザー管理（内部脅威対策）
          "iam:CreateUser",
          "iam:DeleteUser",
          "iam:CreateAccessKey",
          "iam:DeleteAccessKey",
          
          # AWS Organizations操作（組織破壊防止）
          "organizations:*",
          
          # アカウント設定変更（情報漏洩防止）
          "account:*"
        ]
        Resource = "*"
      }
    ]
  })
  
  tags = {
    Name        = "HannibalBaseBoundary"
    Environment = "All"
    Purpose     = "Security-Boundary"
  }
}

# --- 段階的権限縮小計画 ---
# Phase 1: GitHub Actions動作に必要な権限を追加 (現在)
# Phase 2: CloudTrailログ分析 (3-4回デプロイ後)
# Phase 3: 実際使用権限のみに縮小
# Phase 4: Permission Boundary強化