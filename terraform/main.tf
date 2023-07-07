module "eks" {
  source = "./modules/eks"

  region         = var.aws_region
  project_name   = var.project_name
  instance_types = var.aws_instance_types
  cluster_type   = var.cluster_type
}

module "do_k8s" {
  source = "./modules/do_k8s"

  region         = var.do_region
  project_name   = var.project_name
  instance_types = var.do_instance_types
  cluster_type   = var.cluster_type
  do_token       = var.do_token
}
