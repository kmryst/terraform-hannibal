# C:\code\javascript\nestjs-hannibal-3\terraform\outputs.tf

output "ec2_instance_id" {
  value       = aws_instance.backend.id
  description = "NestJSバックエンドが稼働するEC2インスタンスのID"
}

output "ec2_public_ip" {
  # value       = aws_instance.backend.public_ip # EIPを使用するためコメントアウトまたは削除
  value       = aws_eip.backend_eip.public_ip # Elastic IP のアドレスを出力
  description = "NestJSバックエンドが稼働するEC2インスタンスのElastic IPアドレス"
}

output "ec2_public_dns" {
  # value       = aws_instance.backend.public_dns # EIPを使用するためコメントアウトまたは削除
  value       = aws_eip.backend_eip.public_dns # Elastic IP のDNS名を出力
  description = "NestJSバックエンドが稼働するEC2インスタンスのElastic IPのDNS名"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.frontend.bucket
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

# --- Elastic IP の情報を追加 ---
output "backend_eip_address" {
  value       = aws_eip.backend_eip.public_ip
  description = "割り当てられたElastic IPアドレス"
}
