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

  tags = {
    Name = "ngw"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_default_route_table" "main_table" {
  default_route_table_id = aws_vpc.main.default_route_table_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw.id
  }

  tags = {
    Name = "private_router_table"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public_router_table"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.subnet_public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "subnet_app_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.app_subnet_1_cidr
  availability_zone       = "${var.aws_region}${var.app_web_subnet_1_availability_zone}"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.app_subnet_name}_${var.vpc_name}_${var.aws_region}${var.app_web_subnet_1_availability_zone}"
  }

}

resource "aws_subnet" "subnet_app_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.app_subnet_2_cidr
  availability_zone       = "${var.aws_region}${var.app_web_subnet_2_availability_zone}"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.app_subnet_name}_${var.vpc_name}_${var.aws_region}${var.app_web_subnet_2_availability_zone}"

  }

}

resource "aws_subnet" "subnet_db" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.db_subnet_cidr
  availability_zone       = "${var.aws_region}${var.db_subnet_availability_zone}"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.db_subnet_name}_${var.vpc_name}_${var.aws_region}${var.db_subnet_availability_zone}"
  }

}

resource "aws_subnet" "subnet_web_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.web_subnet_1_cidr
  availability_zone       = "${var.aws_region}${var.app_web_subnet_1_availability_zone}"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.web_subnet_name}_${var.vpc_name}_${var.aws_region}${var.app_web_subnet_1_availability_zone}"

  }

}

resource "aws_subnet" "subnet_web_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.web_subnet_2_cidr
  availability_zone       = "${var.aws_region}${var.app_web_subnet_2_availability_zone}"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.web_subnet_name}_${var.vpc_name}_${var.aws_region}${var.app_web_subnet_2_availability_zone}"

  }

}