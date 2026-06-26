# Cloud (EKS) environment — the optional, paid target. Mirrors the local env:
# stand up a cluster, then install nginx ingress + ArgoCD so the same GitOps repo
# deploys the app. Run:
#
#   terraform init
#   terraform apply -var-file=cloud.tfvars
#   aws eks update-kubeconfig --name <cluster_name> --region <region>
#   terraform destroy            # when done — this incurs cost while running

variable "cluster_name" {
  type    = string
  default = "galaxyops"
}
variable "region" {
  type    = string
  default = "us-east-1"
}

provider "aws" {
  region = var.region
}

module "eks" {
  source = "../../modules/eks"

  cluster_name = var.cluster_name
  region       = var.region
}

# Authenticate the Kubernetes/Helm providers to EKS via the AWS CLI token.
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

# nginx ingress (creates an AWS NLB).
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.11.3"
  namespace        = "ingress-nginx"
  create_namespace = true
  wait             = true
  timeout          = 600

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }
}

# ArgoCD.
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.6.12"
  namespace        = "argocd"
  create_namespace = true
  wait             = true
  timeout          = 600
}

output "cluster_name" {
  value = module.eks.cluster_name
}
output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}
output "configure_kubectl" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}
