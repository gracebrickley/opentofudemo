# Terragrunt configuration for Team A stack

include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Dependency on vcluster
dependency "kind-cluster" {
  config_path = "../../platform/kind-cluster"

  mock_outputs = {
    cluster_endpoint = ""
    cluster_ca_certificate = ""
    client_certificate = ""
    client_key = ""
  }

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# Stack-specific inputs
inputs = {
  host_cluster_endpoint = dependency.kind_cluster.outputs.cluster_endpoint
  host_cluster_ca_cert = dependency.kind_cluster.outputs.cluster_ca_certificate
  host_client_cert = dependency.kind_cluster.outputs.client_certificate
  host_client_key = dependency.kind_cluster.outputs.client_key
  team_name        = "team-a"
}

# Hook to ensure kubeconfig files are available in cache directory
# terraform {
#   before_hook "copy_kubeconfigs" {
#     commands = ["plan", "apply", "destroy", "refresh"]
#     execute = [
#       "bash", "-c",
#       "mkdir -p ${get_parent_terragrunt_dir()}/../../platform/vcluster && cp -f ${get_repo_root()}/stacks/platform/vcluster/vcluster-*.kubeconfig ${get_parent_terragrunt_dir()}/../../platform/vcluster/ 2>/dev/null || true"
#     ]
#   }
# }

# Generate provider configuration
# generate "provider" {
#   path      = "provider_generated.tf"
#   if_exists = "overwrite"
#   contents  = <<EOF
# # Providers are configured in main.tf using the vcluster kubeconfig
# EOF
# }
#
