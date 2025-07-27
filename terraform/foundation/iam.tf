# terraform/foundation/iam.tf
# 基盤IAMリソース（Terraformで作成後、管理から除外・永続保持）
# AWS Professional設計: Infrastructure as Code + 永続管理

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
  permissions_boundary = "arn:aws:iam::258632448142:policy/HannibalCICDBoundary"
  
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
          "cloudtrail:CreateTrail",
          "cloudtrail:DescribeTrails",
          "cloudtrail:GetTrailStatus",
          "cloudtrail:ListTags",
          "cloudtrail:PutEventSelectors",
          "cloudtrail:StartLogging",
          "cloudtrail:DeleteTrail",
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
          "ec2:GetSecurityGroupsForVpc",
          "ec2:RevokeSecurityGroupEgress",
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:GetAuthorizationToken",
          "ecr:GetLifecyclePolicy",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:PutLifecyclePolicy",
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
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:DescribeLogGroups",
          "logs:ListTagsForResource",
          "logs:PutRetentionPolicy",
          "cloudwatch:DeleteAlarms",
          "cloudwatch:DeleteDashboards",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:GetDashboard",
          "cloudwatch:ListTagsForResource",
          "cloudwatch:PutDashboard",
          "cloudwatch:PutMetricAlarm",
          "rds:CreateDBInstance",
          "rds:CreateDBSubnetGroup",
          "rds:DeleteDBInstance",
          "rds:DeleteDBSubnetGroup",
          "rds:DescribeDBInstances",
          "rds:DescribeDBSubnetGroups",
          "rds:ListTagsForResource",
          "s3:GetBucketPolicy",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPolicy",
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
          "sns:CreateTopic",
          "sns:DeleteTopic",
          "sns:GetSubscriptionAttributes",
          "sns:GetTopicAttributes",
          "sns:ListTagsForResource",
          "sns:ListTopics",
          "sns:SetTopicAttributes",
          "sns:Subscribe",
          "sts:GetCallerIdentity",
          "kms:CreateGrant",
          "kms:DescribeKey"
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
          "iam:DeletePolicy"
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
  policy_arn = aws_iam_policy.hannibal_cicd_policy_minimal.arn
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