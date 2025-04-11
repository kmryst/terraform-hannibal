output "ec2_public_ip" {
  value       = aws_instance.backend.public_ip
  description = "NestJSバックエンドが稼働するEC2インスタンスのパブリックIPアドレス"
}

output "ec2_public_dns" {
  value       = aws_instance.backend.public_dns
  description = "NestJSバックエンドが稼働するEC2インスタンスのパブリックDNS"
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
