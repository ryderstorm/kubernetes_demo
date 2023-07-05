terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.47.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.4.3"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.4"
    }

    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {}

locals {
  project_name   = var.project_name
  cluster_name   = "${var.project_name}-eks-${random_string.suffix.result}"
  instance_types = var.instance_types
}

resource "random_string" "suffix" {
  length  = 4
  special = false
}

module "vpc" {
  # Load this resource only if the "cluster_type" environment variable is set to "aws"
  count = var.cluster_type == "aws" ? 1 : 0

  source  = "terraform-aws-modules/vpc/aws"
  version = "3.19.0"

  name = "${local.project_name}-vpc"

  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = false

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }
}

module "eks" {
  # Load this resource only if the "cluster_type" environment variable is set to "aws"
  count = var.cluster_type == "aws" ? 1 : 0

  source  = "terraform-aws-modules/eks/aws"
  version = "19.5.1"

  cluster_name    = local.cluster_name
  cluster_version = "1.24"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
  }

  eks_managed_node_groups = {
    one = {
      name           = "node-group-1"
      instance_types = local.instance_types
      min_size       = 1
      max_size       = 3
      desired_size   = 2
    }

    two = {
      name = "node-group-2"

      instance_types = local.instance_types

      min_size     = 1
      max_size     = 2
      desired_size = 1
    }
  }
}
