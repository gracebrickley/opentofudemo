# Terragrunt configuration for KIND cluster stack

include "root" {
  path = find_in_parent_folders("root.hcl")
}

# terraform {
#   before_hook "no_uncommitted_files" {
#     commands = ["init", "plan", "apply"]
#     execute = ["./no_uncommitted_files.sh"]
#   }
#   after_hook "curl_endpoint" {
#     commands = ["apply"]
#     execute = ["./curl_endpoint.sh"]
#   }
# }

# Local variables
locals {
  root_dir = get_repo_root()
}

# Stack-specific inputs
inputs = {
  cluster_name       = "opentofu-platform-demo"
  kubernetes_version = "v1.30.0"
}
