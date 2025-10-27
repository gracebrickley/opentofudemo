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
      VCLUSTER_BIN=""
      if command -v vcluster &> /dev/null; then
        VCLUSTER_BIN="vcluster"
        echo "✓ Using existing vcluster CLI: $(which vcluster)"
      elif [ -f "$HOME/.local/bin/vcluster" ]; then
        VCLUSTER_BIN="$HOME/.local/bin/vcluster"
        echo "✓ Using vcluster CLI from: $VCLUSTER_BIN"
      elif [ -f "${path.module}/vcluster" ]; then
        VCLUSTER_BIN="${path.module}/vcluster"
        echo "✓ Using local vcluster CLI: $VCLUSTER_BIN"
      else
        echo "Installing vcluster CLI to ${path.module}/vcluster..."
        curl -s -L -o ${path.module}/vcluster "https://github.com/loft-sh/vcluster/releases/latest/download/vcluster-darwin-amd64"
        chmod +x ${path.module}/vcluster
        VCLUSTER_BIN="${path.module}/vcluster"
        echo "✓ vcluster CLI installed successfully"
      fi
      
      # Get vcluster kubeconfig using kubectl port-forward method (no vcluster CLI needed)
      echo "Extracting kubeconfig using kubectl..."
      
      # Get the vcluster certificate and server from the secret
      VCLUSTER_SECRET=$(kubectl get secret -n ${each.value.namespace} \
        -l app=${each.value.release_name} \
        -o jsonpath='{.items[0].metadata.name}')
      
      if [ -z "$VCLUSTER_SECRET" ]; then
        echo "Warning: Could not find vcluster secret, using alternative method..."
        
        # Alternative: Use vcluster CLI if available
        if [ -n "$VCLUSTER_BIN" ]; then
          $VCLUSTER_BIN connect ${each.value.release_name} \
            --namespace ${each.value.namespace} \
            --kube-config=${path.module}/vcluster-${each.key}.kubeconfig \
            --update-current=false \
            --background-proxy=false \
            2>/dev/null || true
        fi
      fi
      
      # Verify kubeconfig was created or create a simple one
      if [ ! -f "${path.module}/vcluster-${each.key}.kubeconfig" ]; then
        # Create a basic kubeconfig that uses port-forward
        kubectl get secret vc-${each.value.release_name} \
          -n ${each.value.namespace} \
          -o jsonpath='{.data.config}' | base64 -d \
          > ${path.module}/vcluster-${each.key}.kubeconfig || \
        kubectl config view --raw --minify \
          --kubeconfig=$KUBECONFIG \
          > ${path.module}/vcluster-${each.key}.kubeconfig
      fi
      
      echo "✓ Kubeconfig saved to: ${path.module}/vcluster-${each.key}.kubeconfig"
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

