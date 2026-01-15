variable "zone_name" {
  description = "Route53 Hosted Zone name"
  type        = string
}

variable "records" {
  description = "Route53 record definitions"
  type = map(object({
    type    = string
    ttl     = number
    records = list(string)
  }))
}
