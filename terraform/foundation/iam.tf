# terraform/foundation/iam.tf
# 基盤IAMリソース（Terraformで作成後、管理から除外・永続保持）
# AWS Professional設計: Infrastructure as Code + 永続管理

# --- 0. GitHub Actions OIDC Provider ---
# GitHub Actions が発行する短期トークンを AWS が検証するための IdP 登録
# 適用: aws iam create-open-id-connect-provider で実施（state管理外）
# 参考: https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# --- 新設計: 2ユーザー × 2ロール構成 ---

# --- 1. HannibalDeveloperRole-Dev (統合開発ロール) ---
resource "aws_iam_role" "hannibal_developer_role" {
  name = "HannibalDeveloperRole-Dev"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:user/hannibal"
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
# 信頼ポリシー: GitHub OIDC による AssumeRoleWithWebIdentity（長期キー不要）
# 許可範囲: kmryst/terraform-hannibal の main ブランチからの workflow_dispatch のみ
# 適用: aws iam update-assume-role-policy で実施（state管理外）
resource "aws_iam_role" "hannibal_cicd_role" {
  name                 = "HannibalCICDRole-Dev"
  permissions_boundary = "arn:aws:iam::${var.aws_account_id}:policy/HannibalCICDBoundary"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = "arn:aws:iam::${var.aws_account_id}:oidc-provider/token.actions.githubusercontent.com"
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:kmryst/terraform-hannibal:ref:refs/heads/main"
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
        # IAM権限 (フル操作)
        Effect = "Allow"
        Action = [
          "iam:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# --- 4. HannibalCICDPolicy-Dev-Minimal (最小権限自動デプロイポリシー) ---
resource "aws_iam_policy" "hannibal_cicd_policy_minimal" {
  name        = "HannibalCICDPolicy-Dev-Minimal"
  description = "Minimal CI/CD permissions - CloudTrail analysis + destroy operations"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "access-analyzer:CreateAnalyzer",
          "access-analyzer:GetAnalyzer",
          "access-analyzer:DeleteAnalyzer",
          "access-analyzer:TagResource",
          "access-analyzer:UntagResource",
          "cloudtrail:CreateTrail",
          "cloudtrail:DescribeTrails",
          "cloudtrail:GetTrailStatus",
          "cloudtrail:ListTags",
          "cloudtrail:PutEventSelectors",
          "cloudtrail:StartLogging",
          "cloudtrail:DeleteTrail",
          "cloudtrail:AddTags",
          "cloudtrail:RemoveTags",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcAttribute",
          "ec2:DescribeVpcs",
          "ec2:DescribeNetworkInterfaces",
          "ec2:GetSecurityGroupsForVpc",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:GetAuthorizationToken",
          "ecr:GetLifecyclePolicy",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:PutLifecyclePolicy",
          "ecr:DeleteLifecyclePolicy",
          "ecr:UploadLayerPart",
          "ecs:CreateCluster",
          "ecs:CreateService",
          "ecs:DeleteCluster",
          "ecs:DeleteService",
          "ecs:DeregisterTaskDefinition",
          "ecs:DescribeClusters",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService",
          "ecs:TagResource",
          "ecs:UntagResource",
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:DescribeListenerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTags",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags",
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:DescribeLogGroups",
          "logs:ListTagsForResource",
          "logs:PutRetentionPolicy",
          "logs:TagLogGroup",
          "logs:UntagLogGroup",
          "cloudwatch:DeleteAlarms",
          "cloudwatch:DeleteDashboards",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:GetDashboard",
          "cloudwatch:ListTagsForResource",
          "cloudwatch:PutDashboard",
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:TagResource",
          "cloudwatch:UntagResource",
          "rds:CreateDBInstance",
          "rds:CreateDBSubnetGroup",
          "rds:DeleteDBInstance",
          "rds:DeleteDBSubnetGroup",
          "rds:DescribeDBInstances",
          "rds:DescribeDBSubnetGroups",
          "rds:ListTagsForResource",
          "rds:AddTagsToResource",
          "rds:RemoveTagsFromResource",
          "s3:GetBucketPolicy",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPolicy",
          "s3:DeleteBucketPolicy",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetObjectTagging",
          "s3:PutObjectTagging",
          "s3:DeleteObjectTagging",
          "cloudfront:GetOriginAccessControl",
          "cloudfront:ListOriginAccessControls",
          "cloudfront:CreateDistribution",
          "cloudfront:GetDistribution",
          "cloudfront:UpdateDistribution",
          "cloudfront:DeleteDistribution",
          "cloudfront:ListDistributions",
          "cloudfront:TagResource",
          "cloudfront:UntagResource",
          "cloudfront:ListTagsForResource",
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation",
          "cloudfront:ListInvalidations",
          "sns:CreateTopic",
          "sns:DeleteTopic",
          "sns:GetSubscriptionAttributes",
          "sns:GetTopicAttributes",
          "sns:ListTagsForResource",
          "sns:ListTopics",
          "sns:SetTopicAttributes",
          "sns:Subscribe",
          "sns:TagResource",
          "sns:UntagResource",
          "sts:GetCallerIdentity",
          "kms:CreateGrant",
          "kms:DescribeKey",
          "route53:GetHostedZone",
          "route53:ListHostedZones",
          "route53:ChangeResourceRecordSets",
          "route53:GetChange",
          "route53:ListResourceRecordSets",
          "s3:DeleteBucketPublicAccessBlock",
          "s3:DeleteBucket",
          "s3:GetBucketAcl",
          "s3:ListBucket",
          "cloudwatch:DeleteLogGroup",
          "cloudwatch:DeleteMetricAlarm",
          "cloudwatch:DeleteDashboard",
          "sns:DeleteTopic",
          "sns:Unsubscribe",
          "access-analyzer:DeleteAnalyzer",
          "iam:DeleteRolePolicy",
          "iam:PutRolePolicy"
        ]
        Resource = "*"
      },
      {
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
          "iam:DeletePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:TagPolicy",
          "iam:UntagPolicy"
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

# --- 実際に使用中のポリシー（手動管理・記録用） ---
resource "aws_iam_policy" "hannibal_cicd_policy" {
  name        = "HannibalCICDPolicy-Dev"
  description = "CI/CD automation permissions - ECR push, ECS update, RDS managed password, Secrets Manager (段階的縮小予定)"

  # AWS上の実体は v13 (2026-04-07更新)
  # secretsmanager:* を追加: RDS managed password (manage_master_user_password=true) に必要
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "access-analyzer:*",
          "cloudtrail:*",
          "ec2:*",
          "ecr:*",
          "ecs:*",
          "elasticloadbalancing:*",
          "logs:*",
          "cloudwatch:*",
          "rds:*",
          "secretsmanager:*",
          "s3:*",
          "sns:*",
          "sts:*",
          "kms:*",
          "iam:*",
          "cloudfront:*",
          "route53:*",
          "codedeploy:*",
          "dynamodb:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# --- 実装後の管理方針 ---
# 1. terraform apply でリソース作成
# 2. terraform state rm で管理から除外
# 3. 以降は手動管理・永続保持
# 4. コードは再現性・ドキュメント用に保持

# --- 6. Permission Boundary管理 ---
# HannibalCICDBoundary: CI/CD専用Permission Boundary (手動作成済み)
# arn:aws:iam::258632448142:policy/HannibalCICDBoundary
#
# HannibalECSBoundary: ECS専用Permission Boundary (手動作成済み)
# arn:aws:iam::258632448142:policy/HannibalECSBoundary
# 用途: ECSタスク実行ロールの権限制限

# --- 現在の運用状況 ---
# HannibalCICDRole-Dev: HannibalCICDPolicy-Dev-Minimal v2 アタッチ済み
# deploy.yml + destroy.yml 両対応の最小権限設計
# CloudTrail分析結果に基づく実用的な権限設定

# --- 7. 外部サービス連携用ロール・ポリシー ---

# Cacoo AWS Integration Role (構成図自動生成サービス)
resource "aws_iam_role" "cacoo_integration_role" {
  name = "CacooAWSIntegrationRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.cacoo_aws_account_id}:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "cacoo_readonly_policy" {
  name        = "CacooReadOnlyPolicy"
  description = "Read-only permissions for Cacoo AWS diagram generation"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudfront:ListDistributions",
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeAvailabilityZones",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticache:DescribeCacheSubnetGroups",
          "elasticache:DescribeCacheClusters",
          "rds:DescribeDBInstances",
          "s3:ListAllMyBuckets",
          "s3:GetBucketLocation",
          "sns:ListTopics",
          "sns:GetTopicAttributes",
          "sqs:ListQueues",
          "ec2:DescribeRouteTables",
          "ec2:DescribeNatGateways",
          "ecs:DescribeClusters",
          "ecs:DescribeServices",
          "ecs:DescribeTasks",
          "ecs:ListClusters",
          "ecs:ListServices",
          "ecs:ListTasks",
          "iam:ListRoles",
          "iam:GetRole",
          "iam:ListInstanceProfiles"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cacoo_policy_attachment" {
  role       = aws_iam_role.cacoo_integration_role.name
  policy_arn = aws_iam_policy.cacoo_readonly_policy.arn
}

# --- 8. HannibalPRPlanRole-Dev (PR terraform plan専用ロール) ---
# 信頼ポリシー: GitHub OIDC による AssumeRoleWithWebIdentity
# 許可範囲: kmryst/terraform-hannibal への pull_request イベントのみ
# 用途: PR Check での terraform plan 実行（read-only、apply/destroy 権限なし）
# 設計詳細: docs/operations/pr-terraform-plan-role-design.md
# Permission Boundary: 付与しない。plan policy が read-only に限定されており
#   既存の HannibalCICDBoundary は deploy/destroy 用で流用不適。
#   専用 Boundary の要否は Issue #139 で後続検討する。
resource "aws_iam_role" "hannibal_pr_plan_role" {
  name = "HannibalPRPlanRole-Dev"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = "arn:aws:iam::${var.aws_account_id}:oidc-provider/token.actions.githubusercontent.com"
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:kmryst/terraform-hannibal:pull_request"
          }
        }
      }
    ]
  })
}

# --- 9. HannibalPRPlanPolicy-Dev (PR terraform plan専用ポリシー) ---
# terraform plan に必要な read/list/describe/get 権限のみ
# 含めない: iam:PassRole / create・update・delete・put・modify 系 /
#           s3:PutObject・DeleteObject / dynamodb:PutItem・DeleteItem /
#           secretsmanager:GetSecretValue / ECR push・upload 系
resource "aws_iam_policy" "hannibal_pr_plan_policy" {
  name        = "HannibalPRPlanPolicy-Dev"
  description = "Read-only permissions for PR terraform plan - describe/list/get only, no write or apply operations"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformPlanRead"
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity",
          "ec2:Describe*",
          "elasticloadbalancing:Describe*",
          "ecs:Describe*",
          "ecs:List*",
          "ecr:DescribeRepositories",
          "ecr:GetLifecyclePolicy",
          "ecr:ListTagsForResource",
          "rds:Describe*",
          "rds:ListTagsForResource",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:ListTagsForResource",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:GetDashboard",
          "cloudwatch:ListTagsForResource",
          "sns:GetTopicAttributes",
          "sns:GetSubscriptionAttributes",
          "sns:ListSubscriptionsByTopic",
          "sns:ListTagsForResource",
          "sns:ListTopics",
          "codedeploy:Get*",
          "codedeploy:List*",
          "iam:GetRole",
          "iam:ListRolePolicies",
          "iam:GetRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:ListInstanceProfilesForRole",
          "s3:GetBucketLocation",
          "s3:GetBucketPolicy",
          "s3:GetBucketPublicAccessBlock",
          "s3:GetBucketVersioning",
          "s3:GetEncryptionConfiguration",
          "s3:GetBucketTagging",
          "s3:GetBucketAcl",
          "s3:ListBucket",
          "route53:GetHostedZone",
          "route53:ListHostedZones",
          "route53:ListHostedZonesByName",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResource",
          "cloudfront:GetOriginAccessControl",
          "cloudfront:ListOriginAccessControls",
          "cloudfront:GetDistribution",
          "cloudfront:GetDistributionConfig",
          "cloudfront:ListTagsForResource",
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:ListSecretVersionIds",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid      = "TerraformStateRead"
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::nestjs-hannibal-3-terraform-state/environments/dev/terraform.tfstate"
      }
    ]
  })
}

# --- 10. Policy Attachment (PR plan) ---
resource "aws_iam_role_policy_attachment" "hannibal_pr_plan_policy_attachment" {
  role       = aws_iam_role.hannibal_pr_plan_role.name
  policy_arn = aws_iam_policy.hannibal_pr_plan_policy.arn
}