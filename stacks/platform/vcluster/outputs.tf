# Outputs for vcluster stack
# These outputs are used by team stacks

output "vclusters" {
  description = "Map of created vclusters with their details"
  value = {
    for k, v in var.vclusters : k => {
      name              = v.release_name
      namespace         = v.namespace
      kubeconfig_path   = abspath("${path.module}/vcluster-${k}.kubeconfig")
      status           = "ready"
    }
  }
}

output "vcluster_namespaces" {
  description = "Namespaces where vclusters are deployed"
  value       = { for k, v in kubernetes_namespace.vcluster_namespaces : k => v.metadata[0].name }
}

output "vcluster_ready" {
  description = "Indicates if all vclusters are ready"
  value       = true
  depends_on  = [null_resource.wait_for_vcluster]
}

output "team_kubeconfig_paths" {
  description = "Paths to team-specific kubeconfig files"
  value = {
    for k, v in var.vclusters : k => abspath("${path.module}/vcluster-${k}.kubeconfig")
  }
}

output "vcluster_endpoints" {
  description = "Service endpoints for each vcluster"
  value = {
    for k, v in var.vclusters : k => "https://${v.release_name}.${v.namespace}"
  }
}

