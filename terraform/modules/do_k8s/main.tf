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

resource "digitalocean_kubernetes_cluster" "do_k8s_cluster" {
  # Load this resource only if the "cluster_type" environment variable is set to "digitalocean"
  count = var.cluster_type == "digital-ocean" ? 1 : 0

  name    = "${var.project_name}-dok8s"
  region  = var.region
  version = "1.27.2-do.0"

  node_pool {
    name       = "default-pool"
    size       = var.instance_types[0]
    node_count = 2
  }
}

