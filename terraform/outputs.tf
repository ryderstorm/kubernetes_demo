# output "cluster_endpoint" {
#   description = "Endpoint for EKS control plane"
#   value       = module.eks.cluster_endpoint
# }

# output "aws_region" {
#   description = "AWS region"
#   value       = var.aws_region
# }

# output "cluster_name" {
#   description = "Kubernetes Cluster Name"
#   value       = module.eks.cluster_name
# }

output "cluster_id" {
  description = "Kubernetes Cluster ID"
  value       = module.do_k8s.cluster_id
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.do_k8s.cluster_name
}
