variable "cidr_block" {
    description = "VPC의 CIDR BLOCK"
    type = string
  
}
variable "region_name" {
    description = "region이름"
    type =  string
}

variable "az_count" {
  description = "가용영역의 갯수"
  type = number
}

variable "subnet_bits" {
    description = "서브넷 비트 수"
    type = number
}

variable "public_subnet_count" {
  description = "공인 서브넷의 갯수"
  type = number
}

variable "private_subnet_count" {
  description = "사설 서브넷의 갯수"
  type = number
}

# variable "enable_nat_gateway" {
#   description = "Private subnet이 인터넷으로 나가게 NAT Gateway 생성"
#   type        = bool
#   default     = true
# }
