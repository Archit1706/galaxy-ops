# GalaxyOps

**Production-grade Kubernetes platform that runs [GalaxyServe](https://github.com/Archit1706/galaxy-serve) — a containerized ML inference service — with full GitOps, observability, autoscaling, chaos testing, and security baked in.**

GalaxyServe already ships a container that exposes `/health`, `/ready`, and a Prometheus `/metrics` endpoint. GalaxyOps wraps that service in the infrastructure a real platform team would run it on: Terraform-provisioned Kubernetes, Helm packaging, ArgoCD GitOps, a kube-prometheus-stack observability layer with SLO alerting, HPA autoscaling, PodDisruptionBudgets, NetworkPolicies, and a CI pipeline that builds, scans, and promotes images via git.

> The one-line story: **I build ML services (GalaxyServe) and run them on production-grade Kubernetes infrastructure (GalaxyOps).**

---

## Architecture

```
  Developer push ─► GitHub Actions (build image, Trivy scan, push to GHCR, bump tag)
                                        │  commits new tag to Helm values
                                        ▼
                 Git repo (Helm values = single source of truth)
                                        │
                                  ArgoCD (auto-sync, self-heal)
                                        ▼
   ┌─────────────────── Kubernetes cluster (k3d local / EKS) ───────────────────┐
   │  nginx Ingress ─► GalaxyServe Deployment  ◄─ HPA (scales 1→10 on load)      │
   │      ├─ liveness /health · readiness /ready probes                          │
   │      ├─ resource requests/limits · PodDisruptionBudget · rolling update     │
   │      └─ /metrics ─► scraped by Prometheus (ServiceMonitor)                  │
   │  Observability:  Prometheus + Grafana + Loki + Alertmanager (SLO alerts)    │
   │  Security:       RBAC · NetworkPolicies · non-root · Trivy-scanned images   │
   └────────────────────────────────────────────────────────────────────────────┘
        ▲ chaos: kill pods ─► watch self-heal + SLO hold
        ▲ load:  k6 ─────────► watch HPA scale out, zero-downtime deploy
```

**Flow:** push code → CI builds, scans, and pushes the image, then bumps the tag in git → ArgoCD sees the git change and syncs the cluster → the rollout is zero-downtime → Prometheus scrapes metrics, Grafana shows SLOs, Alertmanager fires on error-budget burn → kill a pod and it self-heals; pour load on it and the HPA scales out.

---

## Tech stack

| Layer | Pick | Why |
|---|---|---|
| Local cluster | **k3d** (k3s-in-Docker) | $0, runs on a laptop, demos everything |
| IaC | **Terraform** | Reproducibly provisions cluster + addons + ArgoCD |
| Packaging | **Helm** | Templated, value-driven deploys |
| GitOps | **ArgoCD** | Declarative, git-as-truth, self-healing |
| Observability | **kube-prometheus-stack** + **Loki** | Metrics, dashboards, alerts, logs in one install |
| Autoscaling | **HPA** (CPU; req/s via prometheus-adapter as stretch) | Scales 1→10 under load |
| Chaos | **kubectl pod-kill loop** → Chaos Mesh (stretch) | Show recovery + SLO hold |
| Security | **Trivy**, RBAC, NetworkPolicies, non-root | Gated in CI |
| Load test | **k6** | Drives the HPA, produces latency numbers |
| CI/CD | **GitHub Actions** | build → scan → push → bump tag |

---

## Repo structure

```
galaxy-ops/
├── terraform/              # IaC: k3d cluster, nginx ingress, namespaces, ArgoCD bootstrap
│   ├── main.tf · variables.tf · outputs.tf · providers.tf
│   ├── modules/cluster/    # reusable k3d cluster module
│   └── envs/{local,cloud}/  # tfvars per environment
├── helm/galaxyserve/       # the application chart
│   ├── Chart.yaml · values.yaml · values-prod.yaml
│   └── templates/          # deployment, service, ingress, hpa, pdb,
│                           # servicemonitor, networkpolicy, rbac, prometheusrule
├── argocd/                 # GitOps
│   ├── bootstrap.yaml      # ArgoCD install (referenced by Terraform)
│   ├── project.yaml        # AppProject with RBAC scoping
│   └── apps/               # app-of-apps: galaxyserve + monitoring + loki
├── monitoring/
│   ├── values-kps.yaml     # kube-prometheus-stack config
│   ├── values-loki.yaml    # loki + promtail
│   ├── dashboards/         # Grafana: latency, QPS, errors, pods, CPU
│   └── alerts/             # SLO burn, crashloop, high-latency rules
├── chaos/experiments/      # pod-kill loop, (stretch) Chaos Mesh network-delay
├── load/k6-script.js       # load generator that drives the HPA
├── .github/workflows/
│   ├── ci.yml              # build → Trivy scan → push GHCR → bump Helm tag
│   └── validate.yml        # helm lint · kubeconform · terraform validate · tflint
└── docs/
    ├── runbook.md          # SRE runbook: each alert → diagnosis → action
    └── slo.md              # SLO + error-budget definition
```

---

## Quickstart (local, $0)

Prerequisites: Docker, [k3d](https://k3d.io), [kubectl](https://kubernetes.io/docs/tasks/tools/), [Helm](https://helm.sh), [Terraform](https://terraform.io), and optionally [k6](https://k6.io).

```bash
# 1. Stand up the whole platform from nothing (cluster + ingress + ArgoCD)
cd terraform/envs/local
terraform init
terraform apply -auto-approve            # ~6 min: cluster + nginx + ArgoCD

# 2. Point ArgoCD at this repo (app-of-apps deploys app + monitoring)
kubectl apply -f ../../../argocd/project.yaml
kubectl apply -f ../../../argocd/apps/root-app.yaml

# 3. Watch it converge
kubectl get applications -n argocd -w

# 4. Reach the service through the ingress
curl -H "Host: galaxyserve.localhost" http://localhost:8080/health
curl -H "Host: galaxyserve.localhost" http://localhost:8080/ready
```

Grafana / ArgoCD / Prometheus UIs are exposed via port-forward — see [docs/runbook.md](docs/runbook.md).

> **Model weights:** GalaxyServe needs a model to report `ready`. Either mount weights
> (`values.yaml → galaxyserve.weights`) or point it at an MLflow registry
> (`galaxyserve.registry.enabled=true`). Without either, the readiness probe stays at 503
> by design — see [GalaxyServe's models/README](https://github.com/Archit1706/galaxy-serve).

---

## Demos that generate the resume metrics

| Demo | Command | What it proves |
|---|---|---|
| **Reproducibility** | `terraform apply` | Full platform stands up in ~6 min from nothing |
| **GitOps self-heal** | `kubectl edit deploy galaxyserve` (change replicas) | ArgoCD reverts the drift automatically |
| **Zero-downtime deploy** | bump tag in git mid-load | 0 dropped requests during rolling update |
| **Autoscaling** | `k6 run load/k6-script.js` | HPA scales 1→10 pods at 70% CPU |
| **Chaos / SRE** | `chaos/experiments/pod-kill.sh` | 99.9% SLO held, <15s recovery |
| **Security** | `trivy image` gate in CI | 0 critical CVEs; non-root, network-isolated pods |

---

## SLOs

- **Availability SLO:** 99.9% of requests succeed (non-5xx) over a 30-day window.
- **Latency SLO:** 95% of `/predict` requests complete under 500ms.

Error-budget burn-rate alerts (fast + slow window) are defined in
[monitoring/alerts/slo.yaml](monitoring/alerts/slo.yaml). Full definition in [docs/slo.md](docs/slo.md).

---

## Status

Built phase by phase (see commit history):

- [x] Phase 0 — Cluster + app, raw manifests, ingress + probes
- [x] Phase 1 — Helm chart
- [x] Phase 2 — Terraform IaC (cluster + ArgoCD bootstrap)
- [x] Phase 3 — GitOps / ArgoCD app-of-apps with self-heal
- [x] Phase 4 — Observability + SLOs (kube-prometheus-stack + Loki)
- [x] Phase 5 — HPA autoscaling + PDB + zero-downtime rollout + k6
- [x] Phase 6 — Chaos + security (NetworkPolicy/RBAC/non-root) + CI/CD

**Stretch:** real EKS deploy · Argo Rollouts canary · sealed-secrets · Tempo tracing · kubecost.

---

## License

MIT — see [LICENSE](LICENSE).
