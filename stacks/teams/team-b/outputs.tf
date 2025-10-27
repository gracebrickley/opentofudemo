# Outputs for Team B stack

output "team_name" {
  description = "Team name"
  value       = var.team_name
}

output "namespace" {
  description = "Application namespace"
  value       = kubernetes_namespace.app.metadata[0].name
}

output "sample_app_service" {
  description = "Sample application service details"
  value = {
    name      = kubernetes_service.sample_app.metadata[0].name
    namespace = kubernetes_service.sample_app.metadata[0].namespace
    endpoint  = "${kubernetes_service.sample_app.metadata[0].name}.${kubernetes_service.sample_app.metadata[0].namespace}.svc.cluster.local"
  }
}

output "redis_endpoint" {
  description = "Redis cache endpoint"
  value       = "${var.team_name}-redis.${kubernetes_namespace.app.metadata[0].name}.svc.cluster.local:6379"
}

output "resources_deployed" {
  description = "List of deployed resources"
  value = [
    "namespace: ${kubernetes_namespace.app.metadata[0].name}",
    "deployment: ${kubernetes_deployment.sample_app.metadata[0].name}",
    "service: ${kubernetes_service.sample_app.metadata[0].name}",
    "redis-deployment: ${kubernetes_deployment.redis.metadata[0].name}",
    "redis-service: ${kubernetes_service.redis.metadata[0].name}",
    "secret: ${kubernetes_secret.redis_credentials.metadata[0].name}"
  ]
}

