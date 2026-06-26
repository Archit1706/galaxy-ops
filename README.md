# GalaxyOps

[![validate](https://github.com/Archit1706/galaxy-ops/actions/workflows/validate.yml/badge.svg)](https://github.com/Archit1706/galaxy-ops/actions/workflows/validate.yml)
&nbsp;![IaC](https://img.shields.io/badge/IaC-Terraform-7B42BC)
&nbsp;![GitOps](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D)
&nbsp;![Packaging](https://img.shields.io/badge/Packaging-Helm-0F1689)
&nbsp;![License](https://img.shields.io/badge/license-MIT-green)

**Production-grade Kubernetes platform that runs [GalaxyServe](https://github.com/Archit1706/galaxy-serve) — a containerized ML inference service — with full GitOps, observability, autoscaling, chaos testing, and security baked in.**

GalaxyServe already ships a container that exposes `/health`, `/ready`, and a Prometheus `/metrics` endpoint. GalaxyOps wraps that service in the infrastructure a real platform team would run it on: Terraform-provisioned Kubernetes, Helm packaging, ArgoCD GitOps, a kube-prometheus-stack observability layer with SLO alerting, HPA autoscaling, PodDisruptionBudgets, NetworkPolicies, and a CI pipeline that security-scans and promotes images via git.

---

## Architecture

```
  galaxy-serve repo ─► CI (build.yml): build image ─► push to GHCR
                                        │  repository_dispatch (new tag)
                                        ▼
  galaxy-ops repo  ─► CI (ci.yml): Trivy scan the image ─► bump Helm tag, commit
                                        │  Helm values = single source of truth
                                        ▼
                                  ArgoCD (auto-sync, self-heal)
                                        ▼
   ┌─────────────────── Kubernetes cluster (k3d local / EKS) ───────────────────┐
   │  nginx Ingress ─► GalaxyServe Deployment  ◄─ HPA (scales 1→10 on load)      │
   │      ├─ liveness /health · readiness /ready probes                          │
   │      ├─ resource requests/limits · PodDisruptionBudget · rolling update     │
   │      └─ /metrics ─► scraped by Prometheus (ServiceMonitor)                  │
   │  Observability:  Prometheus + Grafana + Loki + Promtail + Alertmanager      │
   │  Security:       RBAC · NetworkPolicies · non-root · Trivy-scanned images   │
   └────────────────────────────────────────────────────────────────────────────┘
        ▲ chaos: kill pods ─► watch self-heal + SLO hold
        ▲ load:  k6 ─────────► watch HPA scale out, zero-downtime deploy
```

**Flow:** the GalaxyServe repo builds and pushes the image to GHCR → GalaxyOps CI security-scans that image with Trivy and, on a pass, bumps the Helm image tag in git → ArgoCD sees the commit and syncs the cluster → the rollout is zero-downtime → Prometheus scrapes metrics, Grafana shows SLOs, Alertmanager fires on error-budget burn → kill a pod and it self-heals; pour load on it and the HPA scales out.

---

## Tech stack

| Layer | Pick | Why |
|---|---|---|
| Local cluster | **k3d** (k3s-in-Docker) | $0, runs on a laptop, demos everything |
| IaC | **Terraform** | Reproducibly provisions cluster + addons + ArgoCD |
| Packaging | **Helm** | Templated, value-driven deploys |
| GitOps | **ArgoCD** | Declarative, git-as-truth, self-healing |
| Observability | **kube-prometheus-stack** + **Loki** + **Promtail** | Metrics, dashboards, alerts, logs in one stack |
| Autoscaling | **HPA** (CPU; req/s via prometheus-adapter as stretch) | Scales 1→10 under load |
| Chaos | **kubectl pod-kill loop** → Chaos Mesh (stretch) | Show recovery + SLO hold |
| Security | **Trivy**, RBAC, NetworkPolicies, non-root | Gated in CI |
| Load test | **k6** | Drives the HPA, produces latency numbers |
| CI/CD | **GitHub Actions** | scan published image → bump Helm tag (GitOps promotion) + validate |

---

## Repo structure

```
galaxy-ops/
├── terraform/                      # IaC — env-as-root, reusable platform module
│   ├── main.tf · variables.tf · outputs.tf · providers.tf   # platform module (ns + ingress + ArgoCD)
│   ├── .tflint.hcl
│   ├── modules/cluster/            # reusable k3d cluster module (CLI-driven)
│   ├── modules/eks/                # EKS + VPC module (optional cloud target)
│   └── envs/{local,cloud}/         # per-env root + tfvars (own state)
├── helm/galaxyserve/               # the application chart
│   ├── Chart.yaml · values.yaml · values-prod.yaml · .helmignore
│   └── templates/                  # deployment, service, ingress, hpa, pdb, serviceaccount,
│                                   # servicemonitor, prometheusrule, networkpolicy, rbac, NOTES
├── argocd/                         # GitOps
│   ├── bootstrap.yaml              # ArgoCD install (non-Terraform path)
│   ├── project.yaml                # AppProject with scoped repos/namespaces (RBAC)
│   └── apps/                       # app-of-apps: root, galaxyserve, monitoring,
│                                   # loki, promtail, grafana-dashboards
├── monitoring/
│   ├── values-kps.yaml             # kube-prometheus-stack config
│   ├── values-loki.yaml            # Loki (single-binary)
│   ├── values-promtail.yaml        # Promtail log shipper
│   ├── dashboards/                 # Grafana dashboard JSON + kustomize ConfigMap generator
│   └── alerts/                     # standalone SLO PrometheusRule (mirrors the chart)
├── chaos/
│   ├── README.md
│   └── experiments/                # pod-kill.sh + Chaos Mesh pod-kill & network-delay
├── load/k6-script.js               # load generator that drives the HPA
├── .github/workflows/
│   ├── ci.yml                      # Trivy scan published image → bump Helm tag (GitOps promotion)
│   └── validate.yml                # helm lint · kubeconform · kustomize · terraform validate · tflint · yaml
└── docs/
    ├── runbook.md                  # SRE runbook: each alert → diagnosis → action
    └── slo.md                      # SLO + error-budget definition
```

---

## Quickstart (local, $0)

Prerequisites: Docker, [k3d](https://k3d.io), [kubectl](https://kubernetes.io/docs/tasks/tools/), [Helm](https://helm.sh), [Terraform](https://terraform.io), and optionally [k6](https://k6.io).

```bash
# 1. Stand up the whole platform from nothing (cluster + ingress + ArgoCD)
cd terraform/envs/local
terraform init
terraform apply -var-file=local.tfvars   # ~6 min: k3d cluster + nginx + ArgoCD

# 2. Point ArgoCD at this repo (app-of-apps deploys app + monitoring + logs)
kubectl apply -f ../../../argocd/project.yaml
kubectl apply -f ../../../argocd/apps/root-app.yaml

# 3. Watch it converge (galaxyserve, monitoring, loki, promtail, grafana-dashboards)
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

## Demos & key metrics

Each row is a runnable demo. The "Target" column is the SLO/behaviour the platform
is configured to hold; run the demo to capture the live number.

| Demo | Command | Target |
|---|---|---|
| **Reproducibility** | `terraform apply -var-file=local.tfvars` | Full platform stands up from nothing (~6 min) |
| **GitOps self-heal** | `kubectl -n galaxyserve scale deploy/galaxyserve --replicas=5` | ArgoCD reverts the drift automatically |
| **Zero-downtime deploy** | bump tag in git mid-load | 0 dropped requests during rolling update (`maxUnavailable: 0`) |
| **Autoscaling** | `k6 run -e IMAGE=./galaxy.jpg load/k6-script.js` | HPA scales 1→10 pods at 70% CPU |
| **Chaos / SRE** | `chaos/experiments/pod-kill.sh galaxyserve 10 12` | 99.9% availability SLO held during pod kills |
| **Security** | `trivy image` gate in `ci.yml` | Build blocked on any CRITICAL CVE; non-root, network-isolated pods |

---

## SLOs

- **Availability SLO:** 99.9% of requests succeed (non-5xx) over a 30-day window.
- **Latency SLO:** 95% of `/predict` requests complete under 500ms.

Error-budget burn-rate alerts (fast + slow window) are defined in the chart's
[PrometheusRule](helm/galaxyserve/templates/prometheusrule.yaml) (and mirrored in
[monitoring/alerts/slo.yaml](monitoring/alerts/slo.yaml) for the non-Helm path).
Full definition in [docs/slo.md](docs/slo.md).

---

## CI/CD

Two GitHub Actions workflows, split along the two-repo build/promote boundary:

- **[ci.yml](.github/workflows/ci.yml) — scan & promote.** The image is built and pushed
  to GHCR by GalaxyServe's own `build.yml`. This workflow (triggered by
  `repository_dispatch` from that build, or manually) **Trivy-scans the published image
  and fails on any CRITICAL CVE**, then bumps `image.tag` in `helm/galaxyserve/values.yaml`
  and commits — which ArgoCD picks up and rolls out. No `kubectl`, no manual deploy.
- **[validate.yml](.github/workflows/validate.yml) — pre-merge checks.** Runs on every push/PR.

### Validation results (verified green)

The `validate` workflow passes on `master`. What it actually runs:

| Job | Checks | Result |
|---|---|---|
| `helm` | `helm lint` + `helm template` (default **and** prod values) piped through `kubeconform -strict` | ✅ pass |
| `kustomize` | `kustomize build monitoring/dashboards` renders the dashboard ConfigMap | ✅ pass |
| `terraform` | `terraform fmt -check`, `terraform validate` on **both** env roots, `tflint --recursive` | ✅ pass |
| `yaml` | `yamllint` over `argocd/` and `monitoring/alerts/` | ✅ pass |

Locally verified during the build: the Helm chart lints and renders under default, prod,
and weights-enabled values; both Terraform env roots `init`/`validate` clean; the Grafana
dashboard JSON is valid and the kustomize generator labels it `grafana_dashboard: "1"`.

---

## Possible extensions

Argo Rollouts canary / progressive delivery · sealed-secrets or external-secrets ·
Tempo tracing · kubecost · prometheus-adapter for request-rate-based autoscaling.

---

## License

MIT — see [LICENSE](LICENSE).
