# Data source for existing hosted zone
data "aws_route53_zone" "main" {
  name         = "hamilcar-hannibal.click"
  private_zone = false
}