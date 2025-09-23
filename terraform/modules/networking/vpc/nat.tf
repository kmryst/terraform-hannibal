# NAT Gateway and Route Tables for Three-tier VPC

# --- Elastic IPs for NAT Gateways ---
resource "aws_eip" "nat" {
  for_each = var.environment == "prod" ? {
    "1a" = "ap-northeast-1a"
    "1c" = "ap-northeast-1c"
  } : {
    "1a" = "ap-northeast-1a"
  }
  
  domain = "vpc"
  
  tags = {
    Name        = "${var.project_name}-nat-eip-${each.key}"
    project     = var.project_name
    environment = var.environment
  }
  
  depends_on = [aws_internet_gateway.main]
}

# --- NAT Gateways ---
resource "aws_nat_gateway" "main" {
  for_each = var.environment == "prod" ? {
    "1a" = aws_subnet.public["1a"].id
    "1c" = aws_subnet.public["1c"].id
  } : {
    "1a" = aws_subnet.public["1a"].id
  }
  
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value
  
  tags = {
    Name        = "${var.project_name}-nat-${each.key}"
    project     = var.project_name
    environment = var.environment
  }
  
  depends_on = [aws_internet_gateway.main]
}

# --- Route Tables ---
# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = {
    Name        = "${var.project_name}-public-rt"
    project     = var.project_name
    environment = var.environment
  }
}

# App Route Tables
resource "aws_route_table" "app" {
  for_each = var.environment == "prod" ? {
    "1a" = aws_nat_gateway.main["1a"].id
    "1c" = aws_nat_gateway.main["1c"].id
  } : {
    "1a" = aws_nat_gateway.main["1a"].id
    "1c" = aws_nat_gateway.main["1a"].id  # dev: both use single NAT in 1a
  }
  
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = each.value
  }
  
  tags = {
    Name        = "${var.project_name}-app-rt-${each.key}"
    project     = var.project_name
    environment = var.environment
  }
}

# Data Route Table (no internet access)
resource "aws_route_table" "data" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name        = "${var.project_name}-data-rt"
    project     = var.project_name
    environment = var.environment
  }
}

# --- Route Table Associations ---
# Public Subnet Associations
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public
  
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# App Subnet Associations
resource "aws_route_table_association" "app" {
  for_each = aws_subnet.app
  
  subnet_id      = each.value.id
  route_table_id = aws_route_table.app[each.key].id
}

# Data Subnet Associations
resource "aws_route_table_association" "data" {
  for_each = aws_subnet.data
  
  subnet_id      = each.value.id
  route_table_id = aws_route_table.data.id
}