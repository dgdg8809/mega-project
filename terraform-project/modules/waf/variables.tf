variable "name" {
  description = "WAF WebACL 이름"
  type        = string
}

variable "description" {
  description = "WAF WebACL 설명"
  type        = string
  default     = ""
}

variable "scope" {
  description = "REGIONAL (ALB) 또는 CLOUDFRONT"
  type        = string
  default     = "REGIONAL"
}

variable "default_action" {
  description = "allow 또는 block"
  type        = string
  default     = "allow"
  validation {
    condition     = contains(["allow", "block"], var.default_action)
    error_message = "default_action은 allow 또는 block 이어야 합니다."
  }
}

variable "managed_rule_groups" {
  description = "AWS Managed Rule Groups 리스트"
  type = list(object({
    name            = string   
    vendor_name     = string   
    priority        = number
    override_action = string   
  }))
  default = []
}

variable "rate_limit" {
  description = "Rate-based rule limit"
  type        = number
  default     = 0
}

variable "alb_arn" {
  description = "연결할 ALB ARN"
  type        = string
}

variable "metric_name" {
  description = "CloudWatch metric prefix"
  type        = string
  default     = "iac-waf"
}

variable "log_retention_days" {
  type    = number
  default = 7
}

variable "custom_rules" {
  description = "커스텀 WAF 규칙 리스트"
  type = list(object({
    name     = string
    priority = number
    action   = string  
    statement = object({
      patterns = list(string)
      field_to_match = string  
    })
  }))
  default = []
}
