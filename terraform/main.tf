# Import the EKS module to create the cluster
module "eks" {
  source = "./modules/eks"

  aws_region     = var.aws_region
  project_name   = var.project_name
  instance_types = var.instance_types
}

module "helm" {
  source = "./modules/helm"

  project_name                       = var.project_name
  cluster_name                       = module.eks.cluster_name
  cluster_endpoint                   = module.eks.cluster_endpoint
  cluster_certificate_authority_data = module.eks.cluster_certificate_authority_data
}

