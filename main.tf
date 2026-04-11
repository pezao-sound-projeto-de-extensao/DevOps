resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = var.vpc_name
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidr
  availability_zone = "${var.aws_region}${var.public_subnet_availability_zone}"

  tags = {
    Name = "${var.public_subnet_name}_${var.aws_region}${var.public_subnet_availability_zone}"
  }
}

resource "aws_route" "main_internet_access" {
  route_table_id         = aws_vpc.main.default_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_subnet" "app_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.app_subnet_1_cidr
  availability_zone = "${var.aws_region}${var.app_subnet_1_availability_zone}"

  tags = {
    Name = "${var.app_subnet_name}_${var.aws_region}${var.app_subnet_1_availability_zone}"
  }

}

resource "aws_subnet" "app_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.app_subnet_2_cidr
  availability_zone = "${var.aws_region}${var.app_subnet_2_availability_zone}"

  tags = {
    Name = "${var.app_subnet_name}_${var.aws_region}${var.app_subnet_2_availability_zone}"

  }

}