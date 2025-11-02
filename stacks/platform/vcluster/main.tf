# vcluster Deployment - Layer 2: Virtual Clusters
# Deploys isolated virtual clusters for each team

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
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

variable "vclusters" {
  description = "Map of virtual clusters to create"
  type = map(object({
    namespace     = string
    release_name  = string
    chart_version = optional(string, "0.19.5")
    values        = optional(map(string), {})
  }))
  default = {
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

# Configure providers to use the host cluster kubeconfig
provider "kubernetes" {
  host = var.host_cluster_endpoint

  client_certificate = var.host_client_cert
  client_key = var.host_client_key
  cluster_ca_certificate = var.host_cluster_ca_cert
}

provider "helm" {
  kubernetes {
    host = var.host_cluster_endpoint

    client_certificate = var.host_client_cert
    client_key = var.host_client_key
    cluster_ca_certificate = var.host_cluster_ca_cert
  }
}

# Create namespaces for each vcluster
resource "kubernetes_namespace" "vcluster_namespaces" {
  for_each = var.vclusters

  metadata {
    name = each.value.namespace
    labels = {
      name       = each.value.namespace
      team       = each.key
      managed-by = "terragrunt"
      project    = var.project_name
    }
  }
}

# Deploy vcluster using Helm
resource "helm_release" "vcluster" {
  for_each = var.vclusters

  name       = each.value.release_name
  repository = "https://charts.loft.sh"
  chart      = "vcluster"
  version    = each.value.chart_version
  namespace  = kubernetes_namespace.vcluster_namespaces[each.key].metadata[0].name

  # Basic vcluster configuration
  set {
    name  = "syncer.extraArgs[0]"
    value = "--out-kube-config-server=https://${each.value.release_name}.${each.value.namespace}"
  }

  # Enable service sync
  set {
    name  = "sync.services.enabled"
    value = "true"
  }

  # Enable ingress sync
  set {
    name  = "sync.ingresses.enabled"
    value = "true"
  }

  # Resource limits for demo
  set {
    name  = "vcluster.resources.limits.memory"
    value = "512Mi"
  }

  set {
    name  = "vcluster.resources.limits.cpu"
    value = "500m"
  }

  # Wait for deployment to be ready
  wait    = true
  timeout = 600

  depends_on = [kubernetes_namespace.vcluster_namespaces, kubernetes_service.load_balancer_services]
}
