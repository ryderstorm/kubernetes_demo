output "aws_cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = var.cluster_type == "aws" ? module.eks.cluster_name[0] : "n/a"
}

output "do_cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = var.cluster_type == "digital-ocean" ? module.do_k8s.cluster_name[0] : "n/a"
}

output "do_cluster_id" {
  description = "Kubernetes Cluster ID"
  value       = var.cluster_type == "digital-ocean" ? module.do_k8s.cluster_id[0] : "n/a"
}

