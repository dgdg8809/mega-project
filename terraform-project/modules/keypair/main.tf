resource "tls_private_key" "generate" {
  algorithm = var.key_info.algorithm
  rsa_bits  =  var.key_info.rsa_bits
}

resource "aws_key_pair" "aws" {
  public_key = tls_private_key.generate.public_key_openssh
  key_name   = "${var.region_name}-${lower(var.key_info.algorithm)}-key"
}