# Local (k3d) environment. Instantiates the reusable platform module and owns its
# own state. Run from this directory:
#
#   terraform init
#   terraform apply -var-file=local.tfvars

variable "cluster_name" {
  type    = string
  default = "galaxyops"
}

variable "kubeconfig_path" {
  type    = string
  default = "./kubeconfig"
}

module "platform" {
  source = "../.."

  cluster_name    = var.cluster_name
  kubeconfig_path = var.kubeconfig_path

  servers         = var.servers
  agents          = var.agents
  http_port       = var.http_port
  https_port      = var.https_port
  install_ingress = var.install_ingress
  install_argocd  = var.install_argocd
}

# Extra knobs passed straight through to the module.
variable "servers" {
  type    = number
  default = 1
}
variable "agents" {
  type    = number
  default = 2
}
variable "http_port" {
  type    = number
  default = 8080
}
variable "https_port" {
  type    = number
  default = 8443
}
variable "install_ingress" {
  type    = bool
  default = true
}
variable "install_argocd" {
  type    = bool
  default = true
}

output "cluster_name" {
  value = module.platform.cluster_name
}
output "kube_context" {
  value = module.platform.kube_context
}
output "ingress_url" {
  value = module.platform.ingress_url
}
output "next_steps" {
  value = module.platform.next_steps
}
