# terraform/foundation/iam.tf
# 基盤IAMリソース（永続化済み・手動管理・destroy対象外）
# AWS Professional設計: コード保持、管理のみ外す

# --- A. Core Policy（コア権限）- 環境別分離 ---
# 開発用コアロール
resource "aws_iam_role" "hannibal_core_role_dev" {
  name = "HannibalCoreRole-Dev"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::258632448142:user/hannibal-dev"
        }
      }
    ]
  })
}

# 本番用コアロール
resource "aws_iam_role" "hannibal_core_role_prod" {
  name = "HannibalCoreRole-Prod"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::258632448142:user/hannibal-prod"
        }
      }
    ]
  })
}

# 開発用コアポリシー（幅広い権限）
resource "aws_iam_policy" "hannibal_core_policy_dev" {
  name        = "HannibalCorePolicy-Dev"
  description = "Core permissions for development - ECS/ECR operations, CloudWatch Logs, IAM basic operations"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # ECR認証トークン取得（アカウント単位で必要）
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        # ECRリポジトリ操作権限（リポジトリ単位）
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchDeleteImage",
          "ecr:GetLifecyclePolicy",
          "ecr:PutLifecyclePolicy",
          "ecr:DeleteLifecyclePolicy",
          "ecr:ListTagsForResource",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:CreateRepository",
          "ecr:DeleteRepository",
          "ecr:TagResource",
          "ecr:UntagResource"
        ]
        Resource = "arn:aws:ecr:ap-northeast-1:258632448142:repository/nestjs-hannibal-3"
      },
      {
        # CloudWatch Logs権限 (ログ管理)
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutRetentionPolicy",
          "logs:DeleteLogGroup",
          "logs:GetLogEvents",    # ローカル確認専用: ログ内容を読み取る
          "logs:FilterLogEvents", # ローカル確認専用: ログをフィルタリング
          # GitHub Actions用の追加権限
          "logs:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        # ECS権限 (Cluster, Service, Task Definition)
        Effect = "Allow"
        Action = [
          "ecs:DescribeClusters",
          "ecs:ListClusters",
          "ecs:DescribeServices",
          "ecs:ListServices",
          "ecs:RegisterTaskDefinition",
          "ecs:DeregisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
          "ecs:ListTaskDefinitions",
          "ecs:CreateService",
          "ecs:UpdateService",
          "ecs:DeleteService",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:RunTask",
          "ecs:StopTask",
          "ecs:DeleteCluster",
          "ecs:CreateCluster",
          "ecs:ListContainerInstances",
          "ecs:DescribeContainerInstances"
        ]
        Resource = "*"
      },
      {
        # IAM権限 (Terraform用ロール・ポリシー管理)
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:ListAttachedRolePolicies",
          "iam:PassRole",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:AttachUserPolicy",
          "iam:DetachUserPolicy",
          "iam:ListUserPolicies",
          "iam:ListAttachedUserPolicies",
          "iam:GetUser",
          # GitHub Actions用の追加権限
          "iam:ListPolicyVersions",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          # 追加: インラインポリシー操作用
          "iam:ListRolePolicies",
          "iam:GetRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy"
        ]
        Resource = "*"
      },

      {
        # S3 Terraform Stateファイルアクセス権限
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state",
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state/*",
          "arn:aws:s3:::nestjs-hannibal-3-cloudtrail-logs",
          "arn:aws:s3:::nestjs-hannibal-3-cloudtrail-logs/*"
        ]
      },
      {
        # EC2権限（開発環境用・広めの権限）
        Effect = "Allow"
        Action = [
          "ec2:*"
        ]
        Resource = "*"
      },
      {
        # ELB権限（開発環境用・広めの権限）
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:*",
          "elbv2:*"
        ]
        Resource = "*"
      },
      {
        # S3権限（開発環境用・広めの権限）
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# 本番用コアポリシー（制限権限）
resource "aws_iam_policy" "hannibal_core_policy_prod" {
  name        = "HannibalCorePolicy-Prod"
  description = "Core permissions for production - Limited ECS/ECR operations, CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # ECR認証トークン取得
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        # ECRリポジトリ操作権限（読み取り中心）
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages"
        ]
        Resource = "arn:aws:ecr:ap-northeast-1:258632448142:repository/nestjs-hannibal-3"
      },
      {
        # CloudWatch Logs権限（読み取り中心）
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ]
        Resource = "*"
      },
      {
        # ECS権限（更新のみ）
        Effect = "Allow"
        Action = [
          "ecs:DescribeClusters",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:UpdateService"
        ]
        Resource = "*"
      },
      {
        # S3 Terraform Stateファイルアクセス権限
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state",
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state/*"
        ]
      }
    ]
  })
}

# ポリシーアタッチメント
resource "aws_iam_role_policy_attachment" "hannibal_core_policy_attachment_dev" {
  role       = aws_iam_role.hannibal_core_role_dev.name
  policy_arn = aws_iam_policy.hannibal_core_policy_dev.arn
}

resource "aws_iam_role_policy_attachment" "hannibal_core_policy_attachment_prod" {
  role       = aws_iam_role.hannibal_core_role_prod.name
  policy_arn = aws_iam_policy.hannibal_core_policy_prod.arn
}

# --- B. Infrastructure Policy（インフラ権限）- 環境別分離 ---
# 開発用インフラロール
resource "aws_iam_role" "hannibal_infrastructure_role_dev" {
  name = "HannibalInfrastructureRole-Dev"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::258632448142:user/hannibal-dev"
        }
      }
    ]
  })
}

# 本番用インフラロール
resource "aws_iam_role" "hannibal_infrastructure_role_prod" {
  name = "HannibalInfrastructureRole-Prod"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::258632448142:user/hannibal-prod"
        }
      }
    ]
  })
}

# 開発用インフラポリシー（全権限）
resource "aws_iam_policy" "hannibal_infrastructure_policy_dev" {
  name        = "HannibalInfrastructurePolicy-Dev"
  description = "Infrastructure permissions for development - VPC/EC2/ELB/Route53, S3 bucket management, RDS management"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # ELB権限 (Load Balancer管理)
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:ModifyListener", # ALB Listener設定変更用（503エラー修正対応）
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags",
          "elasticloadbalancing:DescribeTargetHealth", # ローカル確認専用: ALBターゲットヘルス確認
          # GitHub Actions用の追加権限
          "elbv2:DescribeLoadBalancers",
          "elbv2:DeleteLoadBalancer",
          "elbv2:DescribeTargetGroups",
          "elbv2:DeleteTargetGroup",
          "elbv2:DescribeTargetHealth", # ローカル確認専用: ALBターゲットヘルス確認（v2 API）
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTags",
          "elasticloadbalancing:DescribeListenerAttributes",
          "elasticloadbalancing:DescribeLoadBalancerAttributes"
        ]
        Resource = "*"
      },
      {
        # EC2権限 (VPC, Subnet, SG, ENI)
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:AssociateAddress",
          "ec2:DisassociateAddress",
          "ec2:DescribeRouteTables",
          # GitHub Actions用の追加権限
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateTags"
        ]
        Resource = "*"
      },
      {
        # S3バケット・オブジェクト操作権限
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:PutBucketPolicy",
          "s3:GetBucketPolicy",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketPublicAccessBlock",
          "s3:GetObjectTagging",
          "s3:PutObjectTagging",
          "s3:DeleteBucketPolicy",
          "s3:GetAccelerateConfiguration",
          "s3:GetBucketAcl",
          "s3:GetBucketCors",
          "s3:GetBucketEncryption",
          "s3:GetBucketLifecycle",
          "s3:GetBucketLogging",
          "s3:GetBucketObjectLockConfiguration",
          "s3:GetBucketReplication",
          "s3:GetBucketRequestPayment",
          "s3:GetBucketTagging",
          "s3:GetBucketVersioning",
          "s3:GetBucketWebsite",
          "s3:PutBucketTagging",
          "s3:PutBucketVersioning"
        ]
        Resource = [
          "arn:aws:s3:::*",
          "arn:aws:s3:::*/*",
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state/*",
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state"
        ]
      },
      {
        # CloudFrontディストリビューション・キャッシュ無効化権限
        Effect = "Allow"
        Action = [
          "cloudfront:CreateDistribution",
          "cloudfront:UpdateDistribution",
          "cloudfront:GetDistribution",
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation",
          "cloudfront:ListDistributions",
          "cloudfront:ListOriginAccessControls",
          "cloudfront:CreateOriginAccessControl",
          "cloudfront:GetOriginAccessControl",
          "cloudfront:UpdateOriginAccessControl",
          "cloudfront:DeleteOriginAccessControl",
          "cloudfront:TagResource",
          "cloudfront:UntagResource",
          "cloudfront:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        # Route53権限（DNS管理・証明書検証用）
        Effect = "Allow"
        Action = [
          "route53:GetHostedZone",
          "route53:ListHostedZones",
          "route53:ChangeResourceRecordSets",
          "route53:GetChange",
          "route53:ListResourceRecordSets"
        ]
        Resource = "*"
      },
      {
        # RDS権限（PostgreSQL管理）
        Effect = "Allow"
        Action = [
          "rds:CreateDBInstance",
          "rds:DeleteDBInstance",
          "rds:DescribeDBInstances",
          "rds:ModifyDBInstance",
          "rds:CreateDBSubnetGroup",
          "rds:DeleteDBSubnetGroup",
          "rds:DescribeDBSubnetGroups",
          "rds:AddTagsToResource",
          "rds:ListTagsForResource",
          "rds:RemoveTagsFromResource",
          "rds:CreateDBSnapshot",
          "rds:DeleteDBSnapshot",
          "rds:DescribeDBSnapshots",
          "rds:RestoreDBInstanceFromDBSnapshot"
        ]
        Resource = "*"
      },
      {
        # S3 Terraform Stateファイルアクセス権限
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state",
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state/*",
          "arn:aws:s3:::nestjs-hannibal-3-cloudtrail-logs",
          "arn:aws:s3:::nestjs-hannibal-3-cloudtrail-logs/*"
        ]
      },
      {
        # IAM権限（開発環境用・広めの権限）
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:PassRole",
          "iam:GetPolicy",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
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

# 本番用インフラポリシー（読み取りのみ）
resource "aws_iam_policy" "hannibal_infrastructure_policy_prod" {
  name        = "HannibalInfrastructurePolicy-Prod"
  description = "Infrastructure permissions for production - Read-only access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # 読み取り権限のみ
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:Describe*",
          "ec2:Describe*",
          "s3:GetObject",
          "s3:ListBucket",
          "cloudfront:Get*",
          "cloudfront:List*",
          "route53:Get*",
          "route53:List*",
          "rds:Describe*"
        ]
        Resource = "*"
      },
      {
        # S3 Terraform Stateファイルアクセス権限
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state",
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state/*"
        ]
      }
    ]
  })
}

# ポリシーアタッチメント
resource "aws_iam_role_policy_attachment" "hannibal_infrastructure_policy_attachment_dev" {
  role       = aws_iam_role.hannibal_infrastructure_role_dev.name
  policy_arn = aws_iam_policy.hannibal_infrastructure_policy_dev.arn
}

resource "aws_iam_role_policy_attachment" "hannibal_infrastructure_policy_attachment_prod" {
  role       = aws_iam_role.hannibal_infrastructure_role_prod.name
  policy_arn = aws_iam_policy.hannibal_infrastructure_policy_prod.arn
}

# --- C. Monitoring Policy（監視権限）- 環境別分離 ---
# 開発用モニタリングロール
resource "aws_iam_role" "hannibal_monitoring_role_dev" {
  name = "HannibalMonitoringRole-Dev"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::258632448142:user/hannibal-dev"
        }
      }
    ]
  })
}

# 本番用モニタリングロール
resource "aws_iam_role" "hannibal_monitoring_role_prod" {
  name = "HannibalMonitoringRole-Prod"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::258632448142:user/hannibal-prod"
        }
      }
    ]
  })
}

# 開発用モニタリングポリシー（全権限）
resource "aws_iam_policy" "hannibal_monitoring_policy_dev" {
  name        = "HannibalMonitoringPolicy-Dev"
  description = "Monitoring permissions for development - CloudWatch Metrics/Alarms/Dashboard, SNS notifications, CloudTrail"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      {
        # SNS権限（開発環境用・広めの権限）
        Effect = "Allow"
        Action = [
          "sns:*"
        ]
        Resource = "*"
      },
      {
        # CloudWatch権限（開発環境用・広めの権限）
        Effect = "Allow"
        Action = [
          "cloudwatch:*",
          "logs:*"
        ]
        Resource = "*"
      },
      {
        # CloudTrail権限（開発環境用・広めの権限）
        Effect = "Allow"
        Action = [
          "cloudtrail:*"
        ]
        Resource = "*"
      },


      {
        # SES権限（メール送信）
        Effect = "Allow"
        Action = [
          "ses:GetSendQuota",
          "ses:ListIdentities"
        ]
        Resource = "*"
      },
      {
        # S3 Terraform Stateファイルアクセス権限
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state",
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state/*",
          "arn:aws:s3:::nestjs-hannibal-3-cloudtrail-logs",
          "arn:aws:s3:::nestjs-hannibal-3-cloudtrail-logs/*"
        ]
      }
    ]
  })
}

# 本番用モニタリングポリシー（読み取りのみ）
resource "aws_iam_policy" "hannibal_monitoring_policy_prod" {
  name        = "HannibalMonitoringPolicy-Prod"
  description = "Monitoring permissions for production - Read-only access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # 読み取り権限のみ
        Effect = "Allow"
        Action = [
          "cloudwatch:Get*",
          "cloudwatch:List*",
          "cloudwatch:Describe*",
          "logs:Get*",
          "logs:Describe*",
          "logs:FilterLogEvents",
          "sns:Get*",
          "sns:List*",
          "cloudtrail:Get*",
          "cloudtrail:Describe*",
          "cloudtrail:LookupEvents",
          "ses:GetSendQuota",
          "ses:ListIdentities"
        ]
        Resource = "*"
      },
      {
        # S3 Terraform Stateファイルアクセス権限
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state",
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state/*"
        ]
      }
    ]
  })
}

# ポリシーアタッチメント
resource "aws_iam_role_policy_attachment" "hannibal_monitoring_policy_attachment_dev" {
  role       = aws_iam_role.hannibal_monitoring_role_dev.name
  policy_arn = aws_iam_policy.hannibal_monitoring_policy_dev.arn
}

resource "aws_iam_role_policy_attachment" "hannibal_monitoring_policy_attachment_prod" {
  role       = aws_iam_role.hannibal_monitoring_role_prod.name
  policy_arn = aws_iam_policy.hannibal_monitoring_policy_prod.arn
}

# --- D. Security Policy（セキュリティ権限）- 環境別分離 ---
# 開発用セキュリティロール
resource "aws_iam_role" "hannibal_security_role_dev" {
  name = "HannibalSecurityRole-Dev"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::258632448142:user/hannibal-dev"
        }
      }
    ]
  })
}

# 本番用セキュリティロール
resource "aws_iam_role" "hannibal_security_role_prod" {
  name = "HannibalSecurityRole-Prod"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::258632448142:user/hannibal-prod"
        }
      }
    ]
  })
}

# 開発用セキュリティポリシー（制限あり）
resource "aws_iam_policy" "hannibal_security_policy_dev" {
  name        = "HannibalSecurityPolicy-Dev"
  description = "Security permissions for development - Limited ACM certificate management, KMS encryption, Access Analyzer"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # セキュリティ権限（開発用・制限あり）
        Effect = "Allow"
        Action = [
          "acm:List*",
          "acm:Describe*",
          "kms:Describe*",
          "kms:List*",
          "access-analyzer:List*",
          "iam:Get*",
          "iam:List*"
        ]
        Resource = "*"
      },
      {
        # S3 Terraform Stateファイルアクセス権限
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state",
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state/*",
          "arn:aws:s3:::nestjs-hannibal-3-cloudtrail-logs",
          "arn:aws:s3:::nestjs-hannibal-3-cloudtrail-logs/*"
        ]
      }
    ]
  })
}

# 本番用セキュリティポリシー（読み取りのみ）
resource "aws_iam_policy" "hannibal_security_policy_prod" {
  name        = "HannibalSecurityPolicy-Prod"
  description = "Security permissions for production - Read-only access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # 読み取り権限のみ
        Effect = "Allow"
        Action = [
          "acm:List*",
          "acm:Describe*",
          "kms:Describe*",
          "kms:List*",
          "access-analyzer:List*",
          "iam:Get*",
          "iam:List*"
        ]
        Resource = "*"
      },
      {
        # S3 Terraform Stateファイルアクセス権限
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state",
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state/*"
        ]
      }
    ]
  })
}

# ポリシーアタッチメント
resource "aws_iam_role_policy_attachment" "hannibal_security_policy_attachment_dev" {
  role       = aws_iam_role.hannibal_security_role_dev.name
  policy_arn = aws_iam_policy.hannibal_security_policy_dev.arn
}

resource "aws_iam_role_policy_attachment" "hannibal_security_policy_attachment_prod" {
  role       = aws_iam_role.hannibal_security_role_prod.name
  policy_arn = aws_iam_policy.hannibal_security_policy_prod.arn
}

# --- E. Legacy Hannibal Resources（旧hannibal用リソース）- 環境区別なし ---
# 旧hannibal用コアロール
resource "aws_iam_role" "hannibal_core_role" {
  name = "HannibalCoreRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::258632448142:user/hannibal"
        }
      }
    ]
  })
}

# 旧hannibal用インフラロール
resource "aws_iam_role" "hannibal_infrastructure_role" {
  name = "HannibalInfrastructureRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::258632448142:user/hannibal"
        }
      }
    ]
  })
}

# 旧hannibal用モニタリングロール
resource "aws_iam_role" "hannibal_monitoring_role" {
  name = "HannibalMonitoringRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::258632448142:user/hannibal"
        }
      }
    ]
  })
}

# 旧hannibal用セキュリティロール
resource "aws_iam_role" "hannibal_security_role" {
  name = "HannibalSecurityRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::258632448142:user/hannibal"
        }
      }
    ]
  })
}

# 旧hannibal用コアポリシー（幅広い権限）
resource "aws_iam_policy" "hannibal_core_policy" {
  name        = "HannibalCorePolicy"
  description = "Core permissions for legacy hannibal - ECS/ECR operations, CloudWatch Logs, IAM basic operations"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # ECR認証トークン取得（アカウント単位で必要）
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        # ECRリポジトリ操作権限（リポジトリ単位）
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchDeleteImage",
          "ecr:GetLifecyclePolicy",
          "ecr:PutLifecyclePolicy",
          "ecr:DeleteLifecyclePolicy",
          "ecr:ListTagsForResource",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:CreateRepository",
          "ecr:DeleteRepository",
          "ecr:TagResource",
          "ecr:UntagResource"
        ]
        Resource = "arn:aws:ecr:ap-northeast-1:258632448142:repository/nestjs-hannibal-3"
      },
      {
        # CloudWatch Logs権限 (ログ管理)
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutRetentionPolicy",
          "logs:DeleteLogGroup",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        # ECS権限 (Cluster, Service, Task Definition)
        Effect = "Allow"
        Action = [
          "ecs:DescribeClusters",
          "ecs:ListClusters",
          "ecs:DescribeServices",
          "ecs:ListServices",
          "ecs:RegisterTaskDefinition",
          "ecs:DeregisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
          "ecs:ListTaskDefinitions",
          "ecs:CreateService",
          "ecs:UpdateService",
          "ecs:DeleteService",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:RunTask",
          "ecs:StopTask",
          "ecs:DeleteCluster",
          "ecs:CreateCluster",
          "ecs:ListContainerInstances",
          "ecs:DescribeContainerInstances"
        ]
        Resource = "*"
      },
      {
        # IAM権限 (Terraform用ロール・ポリシー管理)
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:ListAttachedRolePolicies",
          "iam:PassRole",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:AttachUserPolicy",
          "iam:DetachUserPolicy",
          "iam:ListUserPolicies",
          "iam:ListAttachedUserPolicies",
          "iam:GetUser",
          "iam:ListPolicyVersions",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:ListRolePolicies",
          "iam:GetRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy"
        ]
        Resource = "*"
      },
      {
        # S3 Terraform Stateファイルアクセス権限
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state",
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state/*",
          "arn:aws:s3:::nestjs-hannibal-3-cloudtrail-logs",
          "arn:aws:s3:::nestjs-hannibal-3-cloudtrail-logs/*"
        ]
      },
      {
        # EC2権限（広めの権限）
        Effect = "Allow"
        Action = [
          "ec2:*"
        ]
        Resource = "*"
      },
      {
        # ELB権限（広めの権限）
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:*",
          "elbv2:*"
        ]
        Resource = "*"
      },
      {
        # S3権限（広めの権限）
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# 旧hannibal用インフラポリシー（全権限）
resource "aws_iam_policy" "hannibal_infrastructure_policy" {
  name        = "HannibalInfrastructurePolicy"
  description = "Infrastructure permissions for legacy hannibal - VPC/EC2/ELB/Route53, S3 bucket management, RDS management"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # ELB権限 (Load Balancer管理)
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:*",
          "elbv2:*"
        ]
        Resource = "*"
      },
      {
        # EC2権限 (VPC, Subnet, SG, ENI)
        Effect = "Allow"
        Action = [
          "ec2:*"
        ]
        Resource = "*"
      },
      {
        # S3バケット・オブジェクト操作権限
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = "*"
      },
      {
        # CloudFrontディストリビューション・キャッシュ無効化権限
        Effect = "Allow"
        Action = [
          "cloudfront:*"
        ]
        Resource = "*"
      },
      {
        # Route53権限（DNS管理・証明書検証用）
        Effect = "Allow"
        Action = [
          "route53:*"
        ]
        Resource = "*"
      },
      {
        # RDS権限（PostgreSQL管理）
        Effect = "Allow"
        Action = [
          "rds:*"
        ]
        Resource = "*"
      },
      {
        # IAM権限（広めの権限）
        Effect = "Allow"
        Action = [
          "iam:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# 旧hannibal用モニタリングポリシー（全権限）
resource "aws_iam_policy" "hannibal_monitoring_policy" {
  name        = "HannibalMonitoringPolicy"
  description = "Monitoring permissions for legacy hannibal - CloudWatch Metrics/Alarms/Dashboard, SNS notifications, CloudTrail"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # SNS権限（広めの権限）
        Effect = "Allow"
        Action = [
          "sns:*"
        ]
        Resource = "*"
      },
      {
        # CloudWatch権限（広めの権限）
        Effect = "Allow"
        Action = [
          "cloudwatch:*",
          "logs:*"
        ]
        Resource = "*"
      },
      {
        # CloudTrail権限（広めの権限）
        Effect = "Allow"
        Action = [
          "cloudtrail:*"
        ]
        Resource = "*"
      },
      {
        # SES権限（メール送信）
        Effect = "Allow"
        Action = [
          "ses:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# 旧hannibal用セキュリティポリシー（制限あり）
resource "aws_iam_policy" "hannibal_security_policy" {
  name        = "HannibalSecurityPolicy"
  description = "Security permissions for legacy hannibal - ACM certificate management, KMS encryption, Access Analyzer"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # セキュリティ権限（制限あり）
        Effect = "Allow"
        Action = [
          "acm:*",
          "kms:*",
          "access-analyzer:*",
          "iam:Get*",
          "iam:List*"
        ]
        Resource = "*"
      }
    ]
  })
}

# 旧hannibal用ポリシーアタッチメント
resource "aws_iam_role_policy_attachment" "hannibal_core_policy_attachment" {
  role       = aws_iam_role.hannibal_core_role.name
  policy_arn = aws_iam_policy.hannibal_core_policy.arn
}

resource "aws_iam_role_policy_attachment" "hannibal_infrastructure_policy_attachment" {
  role       = aws_iam_role.hannibal_infrastructure_role.name
  policy_arn = aws_iam_policy.hannibal_infrastructure_policy.arn
}

resource "aws_iam_role_policy_attachment" "hannibal_monitoring_policy_attachment" {
  role       = aws_iam_role.hannibal_monitoring_role.name
  policy_arn = aws_iam_policy.hannibal_monitoring_policy.arn
}

resource "aws_iam_role_policy_attachment" "hannibal_security_policy_attachment" {
  role       = aws_iam_role.hannibal_security_role.name
  policy_arn = aws_iam_policy.hannibal_security_policy.arn
}

# --- AssumeRole権限は手動で永続化済み ---
# AWS Professional設計: 基盤権限は手動管理でdestroy対象外
# hannibal: HannibalAssumeRolePolicyアタッチ済み（旧ロール用）
# hannibal-dev: AssumeDevRolesポリシーアタッチ済み
# hannibal-prod: AssumeProdRolesポリシーアタッチ済み