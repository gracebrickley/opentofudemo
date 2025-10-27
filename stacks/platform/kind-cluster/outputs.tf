# Outputs for KIND cluster
# These outputs are used by dependent stacks (vcluster)

output "cluster_name" {
  description = "Name of the KIND cluster"
  value       = var.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = data.external.cluster_info.result.endpoint
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate (base64 encoded)"
  value       = data.external.cluster_info.result.ca_data
  sensitive   = true
}

output "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  value       = abspath("${path.module}/kind-kubeconfig")
  depends_on  = [data.local_file.kubeconfig]
}

output "kubeconfig_content" {
  description = "Content of the kubeconfig file"
  value       = data.local_file.kubeconfig.content
  sensitive   = true
}

output "cluster_ready" {
  description = "Indicates if cluster is ready"
  value       = true
  depends_on  = [null_resource.wait_for_cluster, data.local_file.kubeconfig]
}

output "kubernetes_version" {
  description = "Kubernetes version"
  value       = var.kubernetes_version
}

