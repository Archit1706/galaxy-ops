# Provider requirements for the platform module. The provider *configuration*
# (kubeconfig path / context) is supplied by the calling environment root under
# terraform/envs/<env>, so each environment owns its own state and connection.

terraform {
  required_version = ">= 1.5"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.30, < 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.14, < 3.0"
    }
  }
}
