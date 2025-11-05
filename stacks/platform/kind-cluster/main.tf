# KIND Cluster - Layer 1: Host Cluster
# This is the foundation cluster that will host virtual clusters

terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
    kind = {
      source = "tehcyx/kind"
      version = "0.9.0"
    }
  }
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cluster_name" {
  description = "Name of the KIND cluster"
  type        = string
  default     = "opentofu-platform-demo"
}

variable "kubernetes_version" {
  description = "Kubernetes version to use for KIND cluster"
  type        = string
  default     = "v1.30.0"
}

provider "kind" {}

resource "kind_cluster" "default" {
  name           = var.cluster_name
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      kubeadm_config_patches = [
        "kind: InitConfiguration\nnodeRegistration:\n  kubeletExtraArgs:\n    node-labels: \"ingress-ready=true\"\n"
      ]

      extra_port_mappings {
        container_port = 80
        host_port      = 80
      }
      extra_port_mappings {
        container_port = 443
        host_port      = 443
      }
    }

    node {
      role = "worker"
    }
    node {
      role = "worker"
    }
  }
}

resource "local_file" "my_local_file" {
  filename = "${path.module}/kind-kubeconfig"
  content  = kind_cluster.default.kubeconfig
}
