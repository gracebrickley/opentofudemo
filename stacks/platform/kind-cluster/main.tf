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

# Check if KIND is installed
resource "null_resource" "check_kind" {
  provisioner "local-exec" {
    command = "which kind || (echo 'ERROR: kind is not installed. Please install KIND first.' && exit 1)"
  }
}

# Create KIND cluster configuration file
resource "local_file" "kind_config" {
  filename = "${path.module}/kind-config.yaml"
  content  = <<-EOF
    kind: Cluster
    apiVersion: kind.x-k8s.io/v1alpha4
    name: ${var.cluster_name}
    nodes:
    - role: control-plane
      kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
      extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
    - role: worker
    - role: worker
  EOF

  depends_on = [null_resource.check_kind]
}

# Create the KIND cluster
resource "null_resource" "create_kind_cluster" {
  triggers = {
    cluster_name       = var.cluster_name
    config_content     = local_file.kind_config.content
    kubernetes_version = var.kubernetes_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Check if cluster already exists
      if kind get clusters | grep -q "^${var.cluster_name}$"; then
        echo "KIND cluster '${var.cluster_name}' already exists"
      else
        echo "Creating KIND cluster '${var.cluster_name}'..."
        kind create cluster --config ${local_file.kind_config.filename} --image kindest/node:${var.kubernetes_version}
      fi
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "Destroying KIND cluster '${self.triggers.cluster_name}'..."
      kind delete cluster --name ${self.triggers.cluster_name} || true
      
      # Clean up kubeconfig file
      rm -f ${path.module}/kind-kubeconfig || true
    EOT
  }

  depends_on = [local_file.kind_config]
}

# Export kubeconfig explicitly after cluster creation
resource "null_resource" "export_kubeconfig" {
  triggers = {
    cluster_id = null_resource.create_kind_cluster.id
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Exporting kubeconfig for cluster '${var.cluster_name}'..."
      kind export kubeconfig --name ${var.cluster_name} --kubeconfig ${path.module}/kind-kubeconfig
      
      # Verify kubeconfig was created
      if [ -f "${path.module}/kind-kubeconfig" ]; then
        echo "✓ Kubeconfig exported successfully to ${path.module}/kind-kubeconfig"
      else
        echo "✗ Failed to export kubeconfig"
        exit 1
      fi
    EOT
  }

  depends_on = [null_resource.create_kind_cluster]
}

# Wait for cluster to be ready
resource "null_resource" "wait_for_cluster" {
  triggers = {
    cluster_id = null_resource.export_kubeconfig.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for cluster to be ready..."
      export KUBECONFIG=${path.module}/kind-kubeconfig
      
      # Wait for nodes to be ready
      kubectl wait --for=condition=Ready nodes --all --timeout=300s
      
      # Wait for all system pods to be ready
      kubectl wait --for=condition=Ready pods --all -n kube-system --timeout=300s
      
      echo "KIND cluster is ready!"
    EOT
  }

  depends_on = [null_resource.export_kubeconfig]
}

# Get cluster info
data "external" "cluster_info" {
  program = ["bash", "-c", <<-EOT
    export KUBECONFIG=${path.module}/kind-kubeconfig
    
    ENDPOINT=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}')
    CA_DATA=$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
    
    jq -n \
      --arg endpoint "$ENDPOINT" \
      --arg ca_data "$CA_DATA" \
      '{endpoint: $endpoint, ca_data: $ca_data}'
  EOT
  ]

  depends_on = [null_resource.wait_for_cluster]
}

# Read the kubeconfig file that was created
# This uses a data source to ensure it's always reading the actual file
data "local_file" "kubeconfig" {
  filename = "${path.module}/kind-kubeconfig"

  depends_on = [null_resource.export_kubeconfig]
}

