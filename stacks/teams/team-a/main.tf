# Team A Stack - Layer 3: Application Infrastructure
# This stack deploys team-specific resources into their virtual cluster

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

variable "team_name" {
  description = "Team name"
  type        = string
  default     = "team-a"
}

variable "vcluster_kubeconfig_path" {
  description = "Path to the vcluster kubeconfig"
  type        = string
}

# Configure providers to use the vcluster kubeconfig
provider "kubernetes" {
  config_path = var.vcluster_kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = var.vcluster_kubeconfig_path
  }
}

# Create application namespace
resource "kubernetes_namespace" "app" {
  metadata {
    name = "${var.team_name}-apps"
    labels = {
      team       = var.team_name
      managed-by = "terragrunt"
      project    = var.project_name
    }
  }
}

# Create a ConfigMap with team information
resource "kubernetes_config_map" "team_info" {
  metadata {
    name      = "${var.team_name}-info"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  data = {
    team_name   = var.team_name
    environment = var.environment
    provisioned = timestamp()
  }
}

# Deploy a sample application (nginx)
resource "kubernetes_deployment" "sample_app" {
  metadata {
    name      = "${var.team_name}-sample-app"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      app  = "sample-app"
      team = var.team_name
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app  = "sample-app"
        team = var.team_name
      }
    }

    template {
      metadata {
        labels = {
          app  = "sample-app"
          team = var.team_name
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:1.27-alpine"

          port {
            container_port = 80
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 10
            period_seconds        = 5
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 3
          }
        }
      }
    }
  }
}

# Create a service for the sample app
resource "kubernetes_service" "sample_app" {
  metadata {
    name      = "${var.team_name}-sample-app"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    selector = {
      app  = "sample-app"
      team = var.team_name
    }

    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# Deploy PostgreSQL database (using Bitnami chart)
resource "helm_release" "postgres" {
  name       = "${var.team_name}-postgres"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  version    = "13.2.24"
  namespace  = kubernetes_namespace.app.metadata[0].name

  set {
    name  = "auth.username"
    value = var.team_name
  }

  set {
    name  = "auth.password"
    value = "demo-password-${var.team_name}"
  }

  set {
    name  = "auth.database"
    value = "${var.team_name}_db"
  }

  set {
    name  = "primary.resources.requests.memory"
    value = "256Mi"
  }

  set {
    name  = "primary.resources.requests.cpu"
    value = "250m"
  }

  set {
    name  = "primary.resources.limits.memory"
    value = "512Mi"
  }

  set {
    name  = "primary.resources.limits.cpu"
    value = "500m"
  }

  # Persistence disabled for demo
  set {
    name  = "primary.persistence.enabled"
    value = "false"
  }

  wait    = true
  timeout = 600
}

# Create a secret with database connection info
resource "kubernetes_secret" "db_credentials" {
  metadata {
    name      = "${var.team_name}-db-credentials"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  data = {
    host     = "${var.team_name}-postgres-postgresql.${kubernetes_namespace.app.metadata[0].name}.svc.cluster.local"
    port     = "5432"
    database = "${var.team_name}_db"
    username = var.team_name
    password = "demo-password-${var.team_name}"
    url      = "postgresql://${var.team_name}:demo-password-${var.team_name}@${var.team_name}-postgres-postgresql.${kubernetes_namespace.app.metadata[0].name}.svc.cluster.local:5432/${var.team_name}_db"
  }

  type = "Opaque"

  depends_on = [helm_release.postgres]
}

