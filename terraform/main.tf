# GalaxyOps platform — provisions the whole stack from nothing:
#   k3d cluster  ->  namespaces  ->  nginx ingress  ->  ArgoCD
# After `terraform apply`, point ArgoCD at this repo (argocd/apps/root-app.yaml)
# and GitOps takes over deploying the app + monitoring stack.

module "cluster" {
  source = "./modules/cluster"

  cluster_name    = var.cluster_name
  servers         = var.servers
  agents          = var.agents
  api_port        = var.api_port
  http_port       = var.http_port
  https_port      = var.https_port
  k3s_image       = var.k3s_image
  kubeconfig_path = var.kubeconfig_path
  disable_traefik = true
}

# Pre-create application namespaces. Kubernetes auto-labels each with
# kubernetes.io/metadata.name=<name>, which the chart's NetworkPolicies select on.
resource "kubernetes_namespace_v1" "app" {
  for_each = toset(var.app_namespaces)

  metadata {
    name = each.value
    labels = {
      "app.kubernetes.io/part-of" = "galaxyops"
    }
  }

  depends_on = [module.cluster]
}

# nginx ingress controller. k3d maps host ports (http_port/https_port) to the
# in-cluster load balancer, so the controller's LoadBalancer service is reachable
# at http://localhost:${http_port}.
resource "helm_release" "ingress_nginx" {
  count = var.install_ingress ? 1 : 0

  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.ingress_nginx_version
  namespace        = "ingress-nginx"
  create_namespace = true
  wait             = true
  timeout          = 600

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  # Expose controller metrics so Prometheus can scrape the ingress too.
  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }

  depends_on = [module.cluster]
}

# ArgoCD — the GitOps engine. Installed here so `terraform apply` yields a cluster
# that is immediately ready to sync from git.
resource "helm_release" "argocd" {
  count = var.install_argocd ? 1 : 0

  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_version
  namespace        = "argocd"
  create_namespace = true
  wait             = true
  timeout          = 600

  # Run the API server insecurely behind a port-forward (local dev); terminate TLS
  # at the ingress in real environments.
  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }

  depends_on = [module.cluster]
}
