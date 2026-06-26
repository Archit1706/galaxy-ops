variable "cluster_name" {
  type        = string
  description = "Name of the k3d cluster."
  default     = "galaxyops"
}

variable "servers" {
  type        = number
  description = "Number of control-plane nodes."
  default     = 1
}

variable "agents" {
  type        = number
  description = "Number of worker nodes."
  default     = 2
}

variable "api_port" {
  type        = number
  description = "Host port for the Kubernetes API."
  default     = 6443
}

variable "http_port" {
  type        = number
  description = "Host port mapped to ingress HTTP (port 80)."
  default     = 8080
}

variable "https_port" {
  type        = number
  description = "Host port mapped to ingress HTTPS (port 443)."
  default     = 8443
}

variable "k3s_image" {
  type        = string
  description = "k3s image pinning the Kubernetes version."
  default     = "rancher/k3s:v1.30.4-k3s1"
}

variable "kubeconfig_path" {
  type        = string
  description = "Where to write the cluster kubeconfig."
  default     = "./kubeconfig"
}

variable "install_ingress" {
  type        = bool
  description = "Install the nginx ingress controller."
  default     = true
}

variable "install_argocd" {
  type        = bool
  description = "Bootstrap ArgoCD into the cluster."
  default     = true
}

variable "ingress_nginx_version" {
  type        = string
  description = "ingress-nginx Helm chart version."
  default     = "4.11.3"
}

variable "argocd_version" {
  type        = string
  description = "argo-cd Helm chart version."
  default     = "7.6.12"
}

variable "app_namespaces" {
  type        = list(string)
  description = "Application namespaces to pre-create (labeled for NetworkPolicy selectors)."
  default     = ["galaxyserve", "monitoring"]
}
