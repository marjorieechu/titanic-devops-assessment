module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = format("%s-%s-eks", var.tags["environment"], var.tags["project"])
  cluster_version = var.config.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    default = {
      name           = format("%s-node-group", var.tags["environment"])
      instance_types = var.config.node_instance_types

      desired_size = var.config.node_desired_size
      min_size     = var.config.node_min_size
      max_size     = var.config.node_max_size

      disk_size = var.config.node_disk_size

      labels = {
        environment = var.tags["environment"]
      }
    }
  }

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  tags = var.tags
}
