# Route53 DNS for API subdomain
resource "aws_route53_record" "api" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "api.hamilcar-hannibal.click"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# Data source for existing hosted zone
data "aws_route53_zone" "main" {
  name         = "hamilcar-hannibal.click"
  private_zone = false
}