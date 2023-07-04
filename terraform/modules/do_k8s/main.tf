terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}


provider "digitalocean" {
  token = var.do_token
}

locals {
  project_name = var.project_name
  region       = var.region
  # cluster_name   = "${var.project_name}-dok8s-${random_string.suffix.result}"
  cluster_name   = "${var.project_name}-dok8s"
  instance_types = var.instance_types
  cloud_service  = var.cloud_service
}

resource "random_string" "suffix" {
  length  = 4
  special = false
}

# Deploy the actual Kubernetes cluster
resource "digitalocean_kubernetes_cluster" "do_k8s_cluster" {
  # Load this resource only if the "cloud_service" environment variable is set to "digitalocean"
  # count = var.cloud_service == "digitalocean" ? 1 : 0

  name    = local.cluster_name
  region  = local.region
  version = "1.27.2-do.0"

  node_pool {
    name       = "default-pool"
    size       = local.instance_types[0]
    node_count = 2
  }
}

