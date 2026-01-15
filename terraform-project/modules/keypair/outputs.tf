output "private_key" {
  value = tls_private_key.generate.private_key_openssh
}

output "public_key" {
  value = tls_private_key.generate.public_key_openssh
}
output "key_name" {
  value = aws_key_pair.aws.key_name
}