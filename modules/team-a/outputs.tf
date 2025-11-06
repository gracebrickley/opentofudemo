# Outputs for Team A stack

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

output "postgres_endpoint" {
  description = "PostgreSQL database endpoint"
  value       = "${var.team_name}-postgres.${kubernetes_namespace.app.metadata[0].name}.svc.cluster.local:5432"
}

output "database_name" {
  description = "Database name"
  value       = "${var.team_name}_db"
}

output "resources_deployed" {
  description = "List of deployed resources"
  value = [
    "namespace: ${kubernetes_namespace.app.metadata[0].name}",
    "deployment: ${kubernetes_deployment.sample_app.metadata[0].name}",
    "service: ${kubernetes_service.sample_app.metadata[0].name}",
    "postgres-deployment: ${kubernetes_deployment.postgres.metadata[0].name}",
    "postgres-service: ${kubernetes_service.postgres.metadata[0].name}",
    "secret: ${kubernetes_secret.db_credentials.metadata[0].name}"
  ]
}

