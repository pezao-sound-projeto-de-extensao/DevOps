locals {
  app_subnets = {
    app-1 = {
      cidr = var.app_subnet_1_cidr
      az   = "${var.aws_region}${var.app_web_subnet_1_availability_zone}"
      name = "${var.app_subnet_name}-${var.vpc_name}-${var.aws_region}${var.app_web_subnet_1_availability_zone}"
    }
    app-2 = {
      cidr = var.app_subnet_2_cidr
      az   = "${var.aws_region}${var.app_web_subnet_2_availability_zone}"
      name = "${var.app_subnet_name}-${var.vpc_name}-${var.aws_region}${var.app_web_subnet_2_availability_zone}"
    }
  }

  web_subnets = {
    web-1 = {
      cidr = var.web_subnet_1_cidr
      az   = "${var.aws_region}${var.app_web_subnet_1_availability_zone}"
      name = "${var.web_subnet_name}-${var.vpc_name}-${var.aws_region}${var.app_web_subnet_1_availability_zone}"
    }
    web-2 = {
      cidr = var.web_subnet_2_cidr
      az   = "${var.aws_region}${var.app_web_subnet_2_availability_zone}"
      name = "${var.web_subnet_name}-${var.vpc_name}-${var.aws_region}${var.app_web_subnet_2_availability_zone}"
    }
  }

  instances = {
    bastion = {
      name        = "bastion"
      subnet_id   = aws_subnet.public.id
      public_ip   = true
      sg_ids      = [aws_security_group.bastion.id]
      volume_size = 10
    }

    lb = {
      name        = "lb"
      subnet_id   = aws_subnet.public.id
      public_ip   = true
      sg_ids      = [aws_security_group.lb.id]
      volume_size = 12
    }

    web-1 = {
      name        = "web-1"
      subnet_id   = aws_subnet.web["web-1"].id
      public_ip   = false
      sg_ids      = [aws_security_group.web.id]
      volume_size = 15
    }

    web-2 = {
      name        = "web-2"
      subnet_id   = aws_subnet.web["web-2"].id
      public_ip   = false
      sg_ids      = [aws_security_group.web.id]
      volume_size = 15
    }

    app-1 = {
      name        = "app-1"
      subnet_id   = aws_subnet.app["app-1"].id
      public_ip   = false
      sg_ids      = [aws_security_group.app.id]
      volume_size = 15
    }

    app-2 = {
      name        = "app-2"
      subnet_id   = aws_subnet.app["app-2"].id
      public_ip   = false
      sg_ids      = [aws_security_group.app.id]
      volume_size = 15
    }

    db = {
      name        = "db"
      subnet_id   = aws_subnet.db.id
      public_ip   = false
      sg_ids      = [aws_security_group.db.id]
      volume_size = 20
    }
  }
}