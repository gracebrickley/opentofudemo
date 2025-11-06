# Team A Stack - Layer 3: Application Infrastructure
# This stack deploys team-specific resources into their virtual cluster

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

# Deploy PostgreSQL database using native Kubernetes resources
resource "kubernetes_deployment" "postgres" {
  metadata {
    name      = "${var.team_name}-postgres"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      app  = "postgres"
      team = var.team_name
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app  = "postgres"
        team = var.team_name
      }
    }

    template {
      metadata {
        labels = {
          app  = "postgres"
          team = var.team_name
        }
      }

      spec {
        container {
          name  = "postgres"
          image = "postgres:15-alpine"

          env {
            name  = "POSTGRES_USER"
            value = var.team_name
          }

          env {
            name  = "POSTGRES_PASSWORD"
            value = "demo-password-${var.team_name}"
          }

          env {
            name  = "POSTGRES_DB"
            value = "${var.team_name}_db"
          }

          port {
            container_port = 5432
            name          = "postgres"
          }

          resources {
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          liveness_probe {
            exec {
              command = ["pg_isready", "-U", var.team_name]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-U", var.team_name]
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }
      }
    }
  }
}

# Create service for PostgreSQL
resource "kubernetes_service" "postgres" {
  metadata {
    name      = "${var.team_name}-postgres"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    selector = {
      app  = "postgres"
      team = var.team_name
    }

    port {
      port        = 5432
      target_port = 5432
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# Create a secret with database connection info
resource "kubernetes_secret" "db_credentials" {
  metadata {
    name      = "${var.team_name}-db-credentials"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  data = {
    host     = "${var.team_name}-postgres.${kubernetes_namespace.app.metadata[0].name}.svc.cluster.local"
    port     = "5432"
    database = "${var.team_name}_db"
    username = var.team_name
    password = "demo-password-${var.team_name}"
    url      = "postgresql://${var.team_name}:demo-password-${var.team_name}@${var.team_name}-postgres.${kubernetes_namespace.app.metadata[0].name}.svc.cluster.local:5432/${var.team_name}_db"
  }

  type = "Opaque"

  depends_on = [kubernetes_deployment.postgres]
}

# Dummy resource to force re-creation on config changes to test Atlantis
resource "null_resource" "example" {}