output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_ca_certificate" {
  description = "Base64 cluster CA certificate."
  value       = module.eks.cluster_certificate_authority_data
}

output "region" {
  description = "AWS region the cluster runs in."
  value       = var.region
}
