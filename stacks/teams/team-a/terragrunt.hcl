# Terragrunt configuration for Team A stack

include "root" {
  path = find_in_parent_folders()
}

# Dependency on vcluster
dependency "vcluster" {
  config_path = "../../platform/vcluster"
  
  # Mock outputs for planning
  mock_outputs = {
    team_kubeconfig_paths = {
      team-a = "/tmp/mock-team-a-kubeconfig"
    }
    vcluster_ready = true
  }
  
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# Stack-specific inputs
inputs = {
  team_name                = "team-a"
  vcluster_kubeconfig_path = dependency.vcluster.outputs.team_kubeconfig_paths["team-a"]
}

# Generate provider configuration
generate "provider" {
  path      = "provider_generated.tf"
  if_exists = "overwrite"
  contents  = <<EOF
# Providers are configured in main.tf using the vcluster kubeconfig
EOF
}

