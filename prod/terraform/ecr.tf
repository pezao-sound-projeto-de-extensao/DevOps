resource "aws_ecr_repository" "images" {
  for_each = toset(["api", "web"])

  name         = "pezao-sound-${each.key}"
  force_delete = true

  tags = {
    Name = "pezao-sound-${each.key}"
  }
}

resource "null_resource" "build_imagens" {
  for_each = {
    Back-end  = "pezao-sound-api"
    Front-end = "pezao-sound-web"
  }

  depends_on = [aws_ecr_repository.images]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      for k in aws_access_key_id aws_secret_access_key aws_session_token; do
        gh secret set "$${k^^}" --repo pezao-sound-projeto-de-extensao/${each.key} --body "$(aws configure get "$k")"
      done
      gh workflow run ecr.yml --repo pezao-sound-projeto-de-extensao/${each.key} --ref main
      timeout 30m bash -c 'until aws ecr describe-images --region ${var.aws_region} --repository-name ${each.value} --image-ids imageTag=main >/dev/null 2>&1; do sleep 30; done'
    EOT
  }
}
