variable "config" {
  type = object({
    cluster_version     = string
    node_instance_types = list(string)
    node_desired_size   = number
    node_min_size       = number
    node_max_size       = number
    node_disk_size      = number
  })
  description = "EKS cluster configuration"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where EKS will be deployed"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for EKS"
}

variable "tags" {
  type        = map(string)
  description = "Common tags for all resources"
}
