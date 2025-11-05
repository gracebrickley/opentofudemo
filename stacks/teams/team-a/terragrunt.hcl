# Terragrunt configuration for Team A stack

include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Dependency on vcluster
dependency "kind_cluster" {
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

generate "required_variables" {
  path = "required_variables.tf"
  if_exists = "overwrite"
  contents = <<EOF
variable "host_cluster_endpoint" {
  type = string
}

variable "host_cluster_ca_cert" {
  type = string
}

variable "host_client_cert" {
  type = string
}

variable "host_client_key" {
  type = string
}
EOF
}

generate "providers" {
  path = "providers.tf"
  if_exists = "overwrite"
  contents = <<EOF
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
  }
}

provider "kubernetes" {
  host = var.host_cluster_endpoint
  client_certificate = var.host_client_cert
  client_key = var.host_client_key
  cluster_ca_certificate = var.host_cluster_ca_cert
}

EOF
}