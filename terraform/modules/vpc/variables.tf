variable "config" {
  type = object({
    cidr               = string
    azs                = list(string)
    private_subnets    = list(string)
    public_subnets     = list(string)
    enable_nat_gateway = bool
    single_nat_gateway = bool
  })
  description = "VPC configuration"
}

variable "tags" {
  type        = map(string)
  description = "Common tags for all resources"
}
