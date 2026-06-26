variable "cluster_name" {
  type        = string
  description = "Name of the k3d cluster."
  default     = "galaxyops"
}

variable "servers" {
  type        = number
  description = "Number of k3d server (control-plane) nodes."
  default     = 1
}

variable "agents" {
  type        = number
  description = "Number of k3d agent (worker) nodes."
  default     = 2
}

variable "api_port" {
  type        = number
  description = "Host port the Kubernetes API is exposed on."
  default     = 6443
}

variable "http_port" {
  type        = number
  description = "Host port mapped to the cluster load balancer port 80 (ingress HTTP)."
  default     = 8080
}

variable "https_port" {
  type        = number
  description = "Host port mapped to the cluster load balancer port 443 (ingress HTTPS)."
  default     = 8443
}

variable "k3s_image" {
  type        = string
  description = "k3s image (pins the Kubernetes version)."
  default     = "rancher/k3s:v1.30.4-k3s1"
}

variable "kubeconfig_path" {
  type        = string
  description = "Path the cluster kubeconfig is written to."
}

variable "disable_traefik" {
  type        = bool
  description = "Disable the bundled traefik so nginx ingress can own ports 80/443."
  default     = true
}
