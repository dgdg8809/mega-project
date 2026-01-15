variable "region_name" {
  description = "aws 리전 이름"
  type = string
}

variable "az_list" {
  description = "가용 영역 목록"
  type = list(string)
}

variable "public_subnet_ids" {
  description = "공인서브넷의 ID"
  type = list(string)
}

variable "private_subnet_ids" {
  description = "사설 서브넷의 ID"
  type = list(string)
}

variable "ec2_instances" {
  description = "EC2 인스턴스의 정보들"
  type = map(object(
    {
    count         = number
    ami           = string
    instance_type = string
    sg_name       = string
    public        = bool
    user_data     = string
  }
  ))
}


variable "sg_ids" {
  description = "보안 그룹의 ID"
  type = map(string)
}


variable "key_name" {
    description = "ec2 인스턴스의 공개키 이름"
    type = string
  
}

variable "public_key_openssh" {
    description = "ec2 인스턴스의 공개키"
    type = string
  
}
