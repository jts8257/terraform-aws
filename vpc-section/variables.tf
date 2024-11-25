variable "aws_profile" {
  description = "AWS CLI profile to use for authentication"
  type        = string
}


variable "availability_zones" {
  description = "Availability zones to use for subnets"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2b", "ap-northeast-2c"]
}

variable "resource_name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "my"
}

variable "base_cidr" {
  description = "Base CIDR for VPC"
  type        = string
  default     = "10.0.0.0/16"
}
