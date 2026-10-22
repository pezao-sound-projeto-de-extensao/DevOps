resource "aws_ecr_repository" "images" {
  for_each = local.dockerhub_images

  name         = "pezao-sound-${each.key}"
  force_delete = true

  tags = {
    Name = "pezao-sound-${each.key}"
  }
}

resource "null_resource" "importar_imagens_dockerhub" {
  for_each = aws_ecr_repository.images

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${split("/", each.value.repository_url)[0]}
      docker pull ${local.dockerhub_images[each.key]}
      docker tag ${local.dockerhub_images[each.key]} ${each.value.repository_url}:${var.image_tag}
      docker push ${each.value.repository_url}:${var.image_tag}
    EOT
  }
}
