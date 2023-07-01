# see terraform/varibales.tf for additional variable descriptions
variable "project_name" {}

variable "cluster_name" {
  description = "Kubernetes Cluster Name"
  type        = string
}

variable "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "Certificate Authority data for EKS cluster"
  type        = string
}

