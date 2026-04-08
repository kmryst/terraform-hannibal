#!/usr/bin/env bash
# Terraform dev のリモート state が「新規 VPC などだけ作成済み」で、
# IAM / Route53 が AWS に既存のまま state に無いときの import 例。
# 実行前: AWS 認証済み、cd terraform/environments/dev && terraform init
set -euo pipefail
cd "$(dirname "$0")/../terraform/environments/dev"

ACCOUNT_ID="${AWS_ACCOUNT_ID:-258632448142}"
PROJECT="nestjs-hannibal-3"
ZONE_ID="Z06663901XRPJ5V5J5GIW"
DOMAIN="hamilcar-hannibal.click"

terraform import "module.iam.aws_iam_role.ecs_task_execution_role" "${PROJECT}-ecs-task-execution-role"
terraform import "module.iam.aws_iam_policy.ecs_task_execution_secrets_manager_read" \
  "arn:aws:iam::${ACCOUNT_ID}:policy/${PROJECT}-ecs-task-execution-secrets-manager-read"
terraform import "module.iam.aws_iam_role_policy_attachment.ecs_task_execution_role_policy" \
  "${PROJECT}-ecs-task-execution-role/arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
terraform import "module.iam.aws_iam_role_policy_attachment.ecs_task_execution_secrets_manager_read" \
  "${PROJECT}-ecs-task-execution-role/arn:aws:iam::${ACCOUNT_ID}:policy/${PROJECT}-ecs-task-execution-secrets-manager-read"

terraform import "module.codedeploy.aws_iam_role.codedeploy_service_role" "${PROJECT}-codedeploy-service-role"
terraform import "module.codedeploy.aws_iam_role_policy_attachment.codedeploy_service_role" \
  "${PROJECT}-codedeploy-service-role/arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"

terraform import "module.dns_frontend.aws_route53_record.www[0]" "${ZONE_ID}_${DOMAIN}_A"

echo "Done. Run: terraform plan -var-file=... (same vars as CI) then apply if clean."
