output "hosted_zone_id" {
  description = "ID of the Route53 hosted zone"
  value       = data.aws_route53_zone.main.zone_id
}

output "hosted_zone_name" {
  description = "Name of the Route53 hosted zone"
  value       = data.aws_route53_zone.main.name
}