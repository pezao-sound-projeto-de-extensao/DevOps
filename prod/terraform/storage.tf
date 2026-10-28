data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "terraform_data" "s3" {
  for_each = local.s3s
  input    = "${each.value.name}-${data.aws_caller_identity.current.account_id}"

  provisioner "local-exec" {
    command = "aws s3api create-bucket --bucket ${self.input} && aws s3 sync ${path.module}/../../s3-dump s3://${self.input}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "aws s3 rb s3://${self.input} --force"
  }
}
