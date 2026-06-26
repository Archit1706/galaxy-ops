# Local k3d demo settings. One server + two agents is enough to show scheduling,
# PodDisruptionBudgets, and topology spread without straining a laptop.
cluster_name    = "galaxyops"
kubeconfig_path = "./kubeconfig"
servers         = 1
agents          = 2
http_port       = 8080
https_port      = 8443
install_ingress = true
install_argocd  = true
