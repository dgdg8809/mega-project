variable "vpc_id" {
  description = "vpc의 id"
  type        = string

}
variable "region" {
  description = "Region 이름"
  type = object({
    name = string
  })
}
variable "security_group" {
  description = "보안그룹들"
  type = map(object({
    name = string
    ingress_rules = map(object({
      protocol    = string
      from_port   = number
      to_port     = number
      cidr_blocks = list(string)
    }))
    egress_rules = map(object({
      protocol    = string
      from_port   = number
      to_port     = number
      cidr_blocks = list(string)
    }))
  }))
}


