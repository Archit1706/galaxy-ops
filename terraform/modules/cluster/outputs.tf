output "cluster_name" {
  description = "Name of the created k3d cluster."
  value       = var.cluster_name
}

output "kubeconfig_path" {
  description = "Path to the kubeconfig for the created cluster."
  value       = var.kubeconfig_path
}

output "kube_context" {
  description = "kubectl context name for this k3d cluster."
  value       = "k3d-${var.cluster_name}"
}

output "id" {
  description = "Resource id used by dependents to order against cluster creation."
  value       = null_resource.cluster.id
}

output "http_endpoint" {
  description = "Host URL the nginx ingress is reachable on."
  value       = "http://localhost:${var.http_port}"
}
