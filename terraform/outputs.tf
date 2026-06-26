output "cluster_name" {
  description = "Name of the k3d cluster."
  value       = module.cluster.cluster_name
}

output "kube_context" {
  description = "kubectl context for the cluster."
  value       = module.cluster.kube_context
}

output "kubeconfig_path" {
  description = "Path to the kubeconfig file."
  value       = module.cluster.kubeconfig_path
}

output "ingress_url" {
  description = "URL the nginx ingress is reachable on (set the Host header to the app hostname)."
  value       = module.cluster.http_endpoint
}

output "next_steps" {
  description = "What to do after apply."
  value       = <<-EOT
    Platform is up. Now hand the cluster to GitOps:

      kubectl apply -f ../../../argocd/project.yaml
      kubectl apply -f ../../../argocd/apps/root-app.yaml

    ArgoCD UI (admin password):
      kubectl -n argocd port-forward svc/argocd-server 8085:443
      kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

    Reach the service:
      curl -H "Host: galaxyserve.localhost" ${module.cluster.http_endpoint}/health
  EOT
}
