# Route 53で独自ドメインをCloudFrontに向ける
resource "aws_route53_record" "www" {
  count   = var.domain_name != "" && var.hosted_zone_id != "" ? 1 : 0
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }

  depends_on = [var.cloudfront_domain_name]
}

# Route 53でAPIサブドメインをALBに向ける
resource "aws_route53_record" "api" {
  count   = var.api_domain_name != "" && var.hosted_zone_id != "" ? 1 : 0
  zone_id = var.hosted_zone_id
  name    = var.api_domain_name
  type    = "A"

  alias {
    name                   = var.api_alb_dns_name
    zone_id                = var.api_alb_zone_id
    evaluate_target_health = false
  }
}
