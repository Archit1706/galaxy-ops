variable "cluster_name" {
  type        = string
  description = "EKS cluster name."
  default     = "galaxyops"
}

variable "region" {
  type        = string
  description = "AWS region."
  default     = "us-east-1"
}

variable "kubernetes_version" {
  type        = string
  description = "EKS control-plane Kubernetes version."
  default     = "1.30"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the cluster VPC."
  default     = "10.0.0.0/16"
}

variable "node_instance_types" {
  type        = list(string)
  description = "Instance types for the managed node group."
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  type        = number
  description = "Desired number of worker nodes."
  default     = 2
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources."
  default = {
    Project   = "galaxyops"
    ManagedBy = "terraform"
  }
}
