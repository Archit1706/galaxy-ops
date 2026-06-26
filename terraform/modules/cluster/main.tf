# k3d cluster module.
#
# There is no first-class, stable Terraform provider for k3d, so the recommended
# approach is to drive the k3d CLI from a null_resource. The commands are written
# as single lines so they run under both POSIX sh and Windows cmd. Requires `k3d`
# and `kubectl` on PATH at apply time.

terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2"
    }
  }
}

locals {
  traefik_arg = var.disable_traefik ? "--k3s-arg \"--disable=traefik@server:0\"" : ""
}

resource "null_resource" "cluster" {
  triggers = {
    cluster_name    = var.cluster_name
    servers         = var.servers
    agents          = var.agents
    api_port        = var.api_port
    http_port       = var.http_port
    https_port      = var.https_port
    k3s_image       = var.k3s_image
    kubeconfig_path = var.kubeconfig_path
  }

  # Create the cluster and write a standalone kubeconfig.
  provisioner "local-exec" {
    command = "k3d cluster create ${var.cluster_name} --servers ${var.servers} --agents ${var.agents} --api-port ${var.api_port} --image ${var.k3s_image} -p \"${var.http_port}:80@loadbalancer\" -p \"${var.https_port}:443@loadbalancer\" ${local.traefik_arg} --wait"
  }

  provisioner "local-exec" {
    command = "k3d kubeconfig write ${var.cluster_name} --output ${var.kubeconfig_path}"
  }

  # Tear the cluster down on destroy.
  provisioner "local-exec" {
    when    = destroy
    command = "k3d cluster delete ${self.triggers.cluster_name}"
  }
}
