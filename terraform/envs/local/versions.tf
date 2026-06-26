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

  # Local backend for the laptop demo. Swap for an S3/GCS backend in cloud envs.
  backend "local" {
    path = "terraform.tfstate"
  }
}
