# Team B Stack - Layer 3: Application Infrastructure
# This stack deploys team-specific resources into their virtual cluster

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
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
  default     = "team-b"
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

# Configure providers to use the vcluster kubeconfig
provider "kubernetes" {
  host = var.host_cluster_endpoint
  client_certificate = var.host_client_cert
  client_key = var.host_client_key
  cluster_ca_certificate = var.host_cluster_ca_cert
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

# Deploy Redis cache using native Kubernetes resources
resource "kubernetes_deployment" "redis" {
  metadata {
    name      = "${var.team_name}-redis"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      app  = "redis"
      team = var.team_name
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app  = "redis"
        team = var.team_name
      }
    }

    template {
      metadata {
        labels = {
          app  = "redis"
          team = var.team_name
        }
      }

      spec {
        container {
          name  = "redis"
          image = "redis:7-alpine"

          command = ["redis-server"]
          args    = ["--requirepass", "demo-redis-${var.team_name}"]

          port {
            container_port = 6379
            name          = "redis"
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
            tcp_socket {
              port = 6379
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            tcp_socket {
              port = 6379
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }
      }
    }
  }
}

# Create service for Redis
resource "kubernetes_service" "redis" {
  metadata {
    name      = "${var.team_name}-redis"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    selector = {
      app  = "redis"
      team = var.team_name
    }

    port {
      port        = 6379
      target_port = 6379
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# Create a secret with Redis connection info
resource "kubernetes_secret" "redis_credentials" {
  metadata {
    name      = "${var.team_name}-redis-credentials"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  data = {
    host     = "${var.team_name}-redis.${kubernetes_namespace.app.metadata[0].name}.svc.cluster.local"
    port     = "6379"
    password = "demo-redis-${var.team_name}"
    url      = "redis://:demo-redis-${var.team_name}@${var.team_name}-redis.${kubernetes_namespace.app.metadata[0].name}.svc.cluster.local:6379"
  }

  type = "Opaque"

  depends_on = [kubernetes_deployment.redis]
}

