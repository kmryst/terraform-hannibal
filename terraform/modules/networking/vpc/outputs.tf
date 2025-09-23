output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = values(aws_subnet.public)[*].id
}

output "app_subnet_ids" {
  description = "IDs of the app subnets"
  value       = values(aws_subnet.app)[*].id
}

output "data_subnet_ids" {
  description = "IDs of the data subnets"
  value       = values(aws_subnet.data)[*].id
}

output "public_subnets" {
  description = "Public subnet objects"
  value       = aws_subnet.public
}

output "app_subnets" {
  description = "App subnet objects"
  value       = aws_subnet.app
}

output "data_subnets" {
  description = "Data subnet objects"
  value       = aws_subnet.data
}