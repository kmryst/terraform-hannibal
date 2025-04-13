# terraform/outputs.tf (修正版)

output "ec2_instance_id" {
  value       = aws_instance.backend.id
  description = "NestJSバックエンドが稼働するEC2インスタンスのID"
}

# backend_eip_address に統一するため、ec2_public_ip は削除しました。

output "backend_eip_address" {
  value       = aws_eip.backend_eip.public_ip
  description = "NestJSバックエンドEC2インスタンスに割り当てられたElastic IPアドレス"
}

output "ec2_public_dns" {
  value       = aws_eip.backend_eip.public_dns
  description = "NestJSバックエンドEC2インスタンスに割り当てられたElastic IPのパブリックDNS名"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.frontend.bucket # .id ではなく .bucket を使う方が一般的（どちらでも動作はする）
  description = "Reactフロントエンドの静的ファイルを保存するS3バケット名"
}

output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.frontend.domain_name
  description = "CloudFrontディストリビューションのドメイン名"
}

output "cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.frontend.id
  description = "CloudFrontディストリビューションのID"
}

# backend_eip_public_dns は ec2_public_dns で出力しているため不要
# もし backend_eip_public_dns という名前で出力したい場合は、ec2_public_dns をリネームしてください。
# output "backend_eip_public_dns" {
#   value       = aws_eip.backend_eip.public_dns
#   description = "Public DNS name of the backend EC2 instance EIP"
# }
