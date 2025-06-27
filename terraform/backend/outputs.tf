# terraform/backend/outputs.tf

# Terraform apply後に「どのリソースがどんな値になったか」をすぐ確認できる
# 他のTerraformプロジェクトや手作業で必要な値（例：ALBのDNS名、ECSクラスタ名など）をコピペしやすい
# フロントエンドや他システムの設定で「APIのエンドポイント」などを指定する際に便利

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_listener_arn" {
  description = "ARN of the ALB HTTP listener"
  value       = aws_lb_listener.http.arn
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = data.aws_ecr_repository.nestjs_hannibal_3.repository_url
}
