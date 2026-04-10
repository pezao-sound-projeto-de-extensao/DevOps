resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = var.vpc_name
  }
}

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id
  cidr_block = vars.public_subnet_cidr
  availability_zone = "${var.aws_region}${var.public_subnet_avability_zone}"

  tags = {
    Name = var.public_subnet_name
  }
}