# module "eks" {
#   source = "./modules/eks"

#   aws_region     = var.aws_region
#   project_name   = var.project_name
#   instance_types = var.aws_instance_types
#   cluster_type  = var.selected_cluster_type
# }

module "do_k8s" {
  source = "./modules/do_k8s"

  region         = var.do_region
  project_name   = var.project_name
  instance_types = var.do_instance_types
  cluster_type   = var.selected_cluster_type
  do_token       = var.do_token
}

# module "helm" {
#   source = "./modules/helm"

#   project_name                       = var.project_name
#   cluster_name                       = module.eks.cluster_name
#   cluster_endpoint                   = module.eks.cluster_endpoint
#   cluster_certificate_authority_data = module.eks.cluster_certificate_authority_data
# }

