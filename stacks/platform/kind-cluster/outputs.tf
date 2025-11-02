# Outputs for KIND cluster
# These outputs are used by dependent stacks (vcluster)

output "cluster_name" {
  description = "Name of the KIND cluster"
  value       = var.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = kind_cluster.default.endpoint
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate (base64 encoded)"
  value       = kind_cluster.default.cluster_ca_certificate
  sensitive   = true
}

output "client_certificate" {
  value = kind_cluster.default.client_certificate
  sensitive   = true
}

output "client_key" {
  value = kind_cluster.default.client_key
  sensitive   = true
}

output "kubernetes_version" {
  description = "Kubernetes version"
  value       = var.kubernetes_version
}

