variable "config" {
  type = object({
    engine                  = string
    engine_version          = string
    instance_class          = string
    allocated_storage       = number
    max_allocated_storage   = number
    db_name                 = string
    db_username             = string
    multi_az                = bool
    backup_retention_period = number
    deletion_protection     = bool
  })
  description = "RDS configuration"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where RDS will be deployed"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for RDS"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR for security group rules"
}

variable "tags" {
  type        = map(string)
  description = "Common tags for all resources"
}
