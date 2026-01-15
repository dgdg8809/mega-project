variable "region_name" {
  type = string
}

variable "key_info" {
  type = object({
    algorithm = string
    rsa_bits  = optional(number, 2048) 
  })
}