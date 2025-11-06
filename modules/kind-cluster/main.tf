terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    kind = {
      source  = "tehcyx/kind"
      version = "0.9.0"
    }
  }
}

terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    kind = {
      source = "tehcyx/kind"
      version = "0.9.0"
    }
  }
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
