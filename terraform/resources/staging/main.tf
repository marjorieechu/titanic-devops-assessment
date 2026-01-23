locals {
  env = yamldecode(file("${path.module}/../../environments/staging.yaml"))
}

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket         = "staging-titanic-api-tf-state"
    key            = "staging/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "staging-titanic-api-tf-lock"
  }
}

provider "aws" {
  region = local.env.region.primary

  default_tags {
    tags = local.env.tags
  }
}

module "vpc" {
  source = "../../modules/vpc"
  config = local.env.vpc
  tags   = local.env.tags
}

module "eks" {
  source     = "../../modules/eks"
  config     = local.env.eks
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  tags       = local.env.tags
}

module "rds" {
  source     = "../../modules/rds"
  config     = local.env.rds
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  vpc_cidr   = module.vpc.vpc_cidr_block
  tags       = local.env.tags
}
