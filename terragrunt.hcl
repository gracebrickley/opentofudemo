# Root terragrunt configuration
# This file is inherited by all child terragrunt.hcl files

locals {
  # Project root directory
  root_dir = get_repo_root()
  
  # Parse the path to get stack information
  # Example: stacks/platform/kind-cluster -> ["stacks", "platform", "kind-cluster"]
  path_parts = split("/", path_relative_to_include())
  
  # Determine stack type and name
  stack_category = length(local.path_parts) > 1 ? local.path_parts[1] : "unknown"
  stack_name     = length(local.path_parts) > 2 ? local.path_parts[2] : basename(get_terragrunt_dir())
  
  # State file location
  state_file_path = "${local.root_dir}/.terraform-state/${local.stack_category}/${local.stack_name}/terraform.tfstate"
}

# Configure OpenTofu to use local backend for this demo
# In production, you'd use a remote backend (S3, GCS, etc.)
terraform {
  source = "."
  
  extra_arguments "common_vars" {
    commands = get_terraform_commands_that_need_vars()
  }
}

# Remote state configuration (using local backend for demo)
remote_state {
  backend = "local"
  
  config = {
    path = local.state_file_path
  }
  
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
}

# Generate provider configurations
generate "provider_versions" {
  path      = "versions_generated.tf"
  if_exists = "overwrite"
  contents  = <<EOF
terraform {
  required_version = ">= 1.8.0"
  
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}
EOF
}

# Common inputs for all stacks
inputs = {
  project_name = "opentofu-platform-demo"
  environment  = "demo"
  managed_by   = "terragrunt"
}

