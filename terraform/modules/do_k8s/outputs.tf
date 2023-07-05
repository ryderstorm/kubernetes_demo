output "cluster_name" {
  value = digitalocean_kubernetes_cluster.do_k8s_cluster[*].name
}

output "cluster_id" {
  value = digitalocean_kubernetes_cluster.do_k8s_cluster[*].id
}
