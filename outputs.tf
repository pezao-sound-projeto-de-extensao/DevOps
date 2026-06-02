output "efs_dns_name" {
  description = "DNS do EFS para montagem NFS"
  value       = aws_efs_file_system.efs.dns_name
}

output "bastion_public_ip" {
  description = "IP publico do bastion"
  value       = aws_instance.instances["bastion"].public_ip
}

output "web_private_ips" {
  description = "IPs privados das instancias web"
  value = {
    web_1 = aws_instance.instances["web-1"].private_ip
    web_2 = aws_instance.instances["web-2"].private_ip
  }
}

output "app_private_ips" {
  description = "IPs privados das instancias app"
  value = {
    app_1 = aws_instance.instances["app-1"].private_ip
    app_2 = aws_instance.instances["app-2"].private_ip
  }
}
