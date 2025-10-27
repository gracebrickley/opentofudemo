# Terragrunt configuration for Team B stack

include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Dependency on vcluster
dependency "vcluster" {
  config_path = "../../platform/vcluster"
  
  # Mock outputs for planning
  mock_outputs = {
    team_kubeconfig_paths = {
      team-b = "/tmp/mock-team-b-kubeconfig"
    }
    vcluster_ready = true
  }
  
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# Stack-specific inputs
inputs = {
  team_name                = "team-b"
  # Construct absolute path from relative path output
  vcluster_kubeconfig_path = "${get_repo_root()}/${dependency.vcluster.outputs.team_kubeconfig_paths["team-b"]}"
}

# Hook to ensure kubeconfig files are available in cache directory
terraform {
  before_hook "copy_kubeconfigs" {
    commands = ["plan", "apply", "destroy", "refresh"]
    execute  = ["bash", "-c", "mkdir -p ${get_parent_terragrunt_dir()}/../../platform/vcluster && cp -f ${get_repo_root()}/stacks/platform/vcluster/vcluster-*.kubeconfig ${get_parent_terragrunt_dir()}/../../platform/vcluster/ 2>/dev/null || true"]
  }
}

# Generate provider configuration
generate "provider" {
  path      = "provider_generated.tf"
  if_exists = "overwrite"
  contents  = <<EOF
# Providers are configured in main.tf using the vcluster kubeconfig
EOF
}

