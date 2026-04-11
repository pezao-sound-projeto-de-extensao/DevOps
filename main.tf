locals {
  app_subnets = {
    app_1 = {
      cidr = var.app_subnet_1_cidr
      az   = "${var.aws_region}${var.app_web_subnet_1_availability_zone}"
      name = "${var.app_subnet_name}-${var.vpc_name}-${var.aws_region}${var.app_web_subnet_1_availability_zone}"
    }
    app_2 = {
      cidr = var.app_subnet_2_cidr
      az   = "${var.aws_region}${var.app_web_subnet_2_availability_zone}"
      name = "${var.app_subnet_name}-${var.vpc_name}-${var.aws_region}${var.app_web_subnet_2_availability_zone}"
    }
  }

  web_subnets = {
    web_1 = {
      cidr = var.web_subnet_1_cidr
      az   = "${var.aws_region}${var.app_web_subnet_1_availability_zone}"
      name = "${var.web_subnet_name}-${var.vpc_name}-${var.aws_region}${var.app_web_subnet_1_availability_zone}"
    }
    web_2 = {
      cidr = var.web_subnet_2_cidr
      az   = "${var.aws_region}${var.app_web_subnet_2_availability_zone}"
      name = "${var.web_subnet_name}-${var.vpc_name}-${var.aws_region}${var.app_web_subnet_2_availability_zone}"
    }
  }
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = var.vpc_name
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw"
  }
}

resource "aws_subnet" "subnet_public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.aws_region}${var.public_subnet_availability_zone}"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.public_subnet_name}_${var.vpc_name}_${var.aws_region}${var.public_subnet_availability_zone}"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "Ip-ngw"
  }
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.subnet_public.id

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "ngw"
  }
}

resource "aws_default_route_table" "main_table" {
  default_route_table_id = aws_vpc.main.default_route_table_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw.id
  }

  tags = {
    Name = "private-router-table"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-router-table"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.subnet_public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "app" {
  for_each = local.app_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name = each.value.name
  }
}

resource "aws_subnet" "db" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.db_subnet_cidr
  availability_zone       = "${var.aws_region}${var.db_subnet_availability_zone}"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.db_subnet_name}-${var.vpc_name}-${var.aws_region}${var.db_subnet_availability_zone}"
  }
}

resource "aws_subnet" "web" {
  for_each = local.web_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name = each.value.name
  }
}

resource "aws_network_acl" "nacl_db" {
  vpc_id = aws_vpc.main.id

  subnet_ids = [aws_subnet.db.id]

  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "nacl-db"
  }
}

resource "aws_network_acl" "nacl_app" {
  vpc_id = aws_vpc.main.id

  subnet_ids = [for subnet in values(aws_subnet.app) : subnet.id]

  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.nacl_app_cidr
    from_port  = 80
    to_port    = 80
  }

  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "nacl-app"
  }
}

resource "aws_network_acl" "nacl_web" {
  vpc_id = aws_vpc.main.id

  subnet_ids = [for subnet in values(aws_subnet.web) : subnet.id]

  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.nacl_web_cidr
    from_port  = 80
    to_port    = 80
  }

  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "nacl-web"
  }
}