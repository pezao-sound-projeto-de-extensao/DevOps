resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventories/production/hosts.ini"
  file_permission = "0644"

  content = templatefile("${path.module}/scripts/hosts.ini.tftpl", {
    bastion_public_ip = aws_instance.instances["bastion"].public_ip
    web_1_private_ip  = aws_instance.instances["web-1"].private_ip
    web_2_private_ip  = aws_instance.instances["web-2"].private_ip
    app_1_private_ip  = aws_instance.instances["app-1"].private_ip
    app_2_private_ip  = aws_instance.instances["app-2"].private_ip
    private_key_path  = "../terraform/${var.key_name}.pem"
  })
}

resource "local_file" "ansible_all_vars" {
  filename        = "${path.module}/../ansible/inventories/production/group_vars/all.yml"
  file_permission = "0644"

  content = yamlencode({
    db_host     = aws_db_instance.instance_db.address
    db_port     = 3306
    db_name     = var.db_name
    db_username = var.db_username
    db_password = var.db_password
    //s3 = aws_s3_bucket.s3["blobs"].bucket
    s3     = "blobs-437920188033-us-east-1-an"
    secret = var.jwt_secret
    cors   = "http://${aws_lb.main.dns_name}"
  })
}

resource "local_file" "ansible_app_vars" {
  filename        = "${path.module}/../ansible/inventories/production/group_vars/app.yml"
  file_permission = "0644"

  content = yamlencode({
    app_image         = "${aws_ecr_repository.images["api"].repository_url}:main"
    web_image         = "${aws_ecr_repository.images["web"].repository_url}:main"
    alb_url           = "http://${aws_lb.main.dns_name}/api"
    rabbitmq_username = var.rabbitmq_username
    rabbitmq_password = var.rabbitmq_password
    mail_host         = var.mail_host
    mail_username     = var.mail_username
    mail_password     = var.mail_password
    mail_from         = var.mail_from
  })
}

resource "null_resource" "configurando_db" {
  depends_on = [
    local_file.ansible_inventory,
    local_file.ansible_all_vars,
    aws_db_instance.instance_db
  ]

  provisioner "local-exec" {
    working_dir = "${path.module}/../ansible"
    command     = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventories/production/hosts.ini playbooks/db.yml"
  }
}

resource "null_resource" "configurando_instancias" {
  depends_on = [
    local_file.ansible_inventory,
    local_file.ansible_all_vars,
    local_file.ansible_app_vars,
    aws_instance.instances,
    null_resource.configurando_db,
    null_resource.build_imagens
  ]

  provisioner "local-exec" {
    working_dir = "${path.module}/../ansible"
    command     = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventories/production/hosts.ini playbooks/deploy.yml"
  }
}
