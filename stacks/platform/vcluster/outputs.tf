# Outputs for vcluster stack
# These outputs are used by team stacks

output "vclusters" {
  description = "Map of created vclusters with their details"
  value = {
    for k, v in var.vclusters : k => {
      name              = v.release_name
      namespace         = v.namespace
      kubeconfig_path   = abspath("${path.root}/../../vcluster/vcluster-${k}.kubeconfig")
      status           = "ready"
    }
  }
}

output "vcluster_namespaces" {
  description = "Namespaces where vclusters are deployed"
  value       = { for k, v in kubernetes_namespace.vcluster_namespaces : k => v.metadata[0].name }
}

output "team_kubeconfig_paths" {
  description = "Paths to team-specific kubeconfig files (relative to repo root)"
  value = {
    for k, v in var.vclusters : k => "stacks/platform/vcluster/vcluster-${k}.kubeconfig"
  }
}

output "vcluster_endpoints" {
  description = "Service endpoints for each vcluster"
  value = {
    for k, v in var.vclusters : k => "https://${v.release_name}.${v.namespace}"
  }
}

