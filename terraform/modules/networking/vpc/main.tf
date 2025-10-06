# Three-tier VPC Architecture
# Presentation (Public) / Application (Private) / Data (Private)

# --- VPC ---
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    project     = var.project_name
    environment = var.environment
  }
}

# --- Internet Gateway ---
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-igw"
    project     = var.project_name
    environment = var.environment
  }
}

# --- Subnets ---
# Public Subnets (Presentation Tier)
resource "aws_subnet" "public" {
  for_each = {
    "1a" = { cidr = "10.0.1.0/24", az = "ap-northeast-1a" }
    "1c" = { cidr = "10.0.2.0/24", az = "ap-northeast-1c" }
  }

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-${each.key}"
    project     = var.project_name
    environment = var.environment
    tier        = "public"
  }
}

# App Subnets (Application Tier)
resource "aws_subnet" "app" {
  for_each = {
    "1a" = { cidr = "10.0.11.0/24", az = "ap-northeast-1a" }
    "1c" = { cidr = "10.0.12.0/24", az = "ap-northeast-1c" }
  }

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = {
    Name        = "${var.project_name}-app-${each.key}"
    project     = var.project_name
    environment = var.environment
    tier        = "app"
  }
}

# Data Subnets (Data Tier)
resource "aws_subnet" "data" {
  for_each = {
    "1a" = { cidr = "10.0.21.0/24", az = "ap-northeast-1a" }
    "1c" = { cidr = "10.0.22.0/24", az = "ap-northeast-1c" }
  }

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = {
    Name        = "${var.project_name}-data-${each.key}"
    project     = var.project_name
    environment = var.environment
    tier        = "data"
  }
}