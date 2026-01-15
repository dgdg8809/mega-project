output "record_fqdns" {
  description = "FQDNs of Route53 records"
  value = {
    for k, v in aws_route53_record.this :
    k => v.fqdn
  }
}
