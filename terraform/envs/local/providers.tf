# Connection config for the local k3d cluster. The platform module writes the
# kubeconfig to var.kubeconfig_path during apply; these providers read it.
provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = "k3d-${var.cluster_name}"
}

provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = "k3d-${var.cluster_name}"
  }
}
