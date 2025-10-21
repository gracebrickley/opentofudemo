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

variable "host_kubeconfig_path" {
  description = "Path to the host cluster kubeconfig"
  type        = string
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
  config_path = var.host_kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = var.host_kubeconfig_path
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

  depends_on = [kubernetes_namespace.vcluster_namespaces]
}

# Wait for vcluster to be ready
resource "null_resource" "wait_for_vcluster" {
  for_each = var.vclusters

  triggers = {
    vcluster_id = helm_release.vcluster[each.key].id
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for vcluster ${each.key} to be ready..."
      export KUBECONFIG=${var.host_kubeconfig_path}
      
      # Wait for statefulset to be ready
      kubectl rollout status statefulset/${each.value.release_name} \
        -n ${each.value.namespace} \
        --timeout=300s
      
      echo "vcluster ${each.key} is ready!"
    EOT
  }

  depends_on = [helm_release.vcluster]
}

# Extract kubeconfig for each vcluster
resource "null_resource" "extract_kubeconfig" {
  for_each = var.vclusters

  triggers = {
    vcluster_ready = null_resource.wait_for_vcluster[each.key].id
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Extracting kubeconfig for vcluster ${each.key}..."
      export KUBECONFIG=${var.host_kubeconfig_path}
      
      # Install vcluster CLI if not present
      if ! command -v vcluster &> /dev/null; then
        echo "Installing vcluster CLI..."
        curl -L -o vcluster "https://github.com/loft-sh/vcluster/releases/latest/download/vcluster-darwin-amd64"
        chmod +x vcluster
        sudo mv vcluster /usr/local/bin/ || mv vcluster ~/vcluster
        export PATH="$PATH:$HOME"
      fi
      
      # Get vcluster kubeconfig
      vcluster connect ${each.value.release_name} \
        --namespace ${each.value.namespace} \
        --server=https://${each.value.release_name}.${each.value.namespace} \
        --kube-config=${path.module}/vcluster-${each.key}.kubeconfig \
        --update-current=false
      
      # Also create a cleaner kubeconfig
      kubectl config view --raw --minify \
        --kubeconfig=${path.module}/vcluster-${each.key}.kubeconfig \
        > ${path.module}/vcluster-${each.key}-clean.kubeconfig
      
      echo "Kubeconfig saved to: ${path.module}/vcluster-${each.key}.kubeconfig"
    EOT
  }

  depends_on = [null_resource.wait_for_vcluster]
}

# Create marker files for kubeconfigs
resource "local_file" "vcluster_kubeconfig_marker" {
  for_each = var.vclusters

  filename = "${path.module}/vcluster-${each.key}.kubeconfig"
  content  = "# Kubeconfig will be generated by vcluster CLI"

  lifecycle {
    ignore_changes = [content]
  }

  depends_on = [null_resource.extract_kubeconfig]
}

