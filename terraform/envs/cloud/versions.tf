terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40"
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

  # Use a remote backend in real use. Left as local here for the demo; uncomment
  # and configure to share state across a team.
  # backend "s3" {
  #   bucket = "galaxyops-tfstate"
  #   key    = "cloud/terraform.tfstate"
  #   region = "us-east-1"
  # }
}
