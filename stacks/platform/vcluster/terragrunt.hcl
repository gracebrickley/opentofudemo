# Terragrunt configuration for vcluster stack

include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Dependency on KIND cluster
dependency "kind_cluster" {
  config_path = "../kind-cluster"
  
  # Mock outputs for planning
  mock_outputs = {
    kubeconfig_path = "/tmp/mock-kubeconfig"
    cluster_ready   = true
    cluster_name    = "mock-cluster"
  }
  
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# Local variables
locals {
  root_dir = get_repo_root()
}

# Stack-specific inputs
inputs = {
  host_cluster_endpoint = dependency.kind_cluster.outputs.cluster_endpoint
  host_cluster_ca_cert = dependency.kind_cluster.outputs.cluster_ca_certificate
  host_client_cert = dependency.kind_cluster.outputs.client_certificate
  host_client_key = dependency.kind_cluster.outputs.client_key

  vclusters = {
    team-a = {
      namespace    = "vcluster-team-a"
      release_name = "vcluster-team-a"
    }
    team-b = {
      namespace    = "vcluster-team-b"
      release_name = "vcluster-team-b"
    }
  }
}

# Generate additional provider configuration
generate "provider" {
  path      = "provider_generated.tf"
  if_exists = "overwrite"
  contents  = <<EOF
# Providers are configured in main.tf using the host kubeconfig
EOF
}

