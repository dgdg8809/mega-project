output "public_ips" {
  description = "생성된 EC2들의 공인 IP (public=true 인스턴스만 유효)"
  value       = { for k, inst in aws_instance.ec2s : k => inst.public_ip }
}

output "instance_ids" {
  description = "생성된 EC2 인스턴스 ID"
  value       = { for k, inst in aws_instance.ec2s : k => inst.id }
}

output "public_dns" {
  description = "EC2 public DNS per instance key"
  value       = { for k, inst in aws_instance.ec2s : k => inst.public_dns }
}
