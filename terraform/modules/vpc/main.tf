module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = format("%s-%s-vpc", var.tags["environment"], var.tags["project"])
  cidr = var.config.cidr

  azs             = var.config.azs
  private_subnets = var.config.private_subnets
  public_subnets  = var.config.public_subnets

  enable_nat_gateway   = var.config.enable_nat_gateway
  single_nat_gateway   = var.config.single_nat_gateway
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = var.tags
}
