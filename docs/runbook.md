# SRE Runbook — GalaxyServe on GalaxyOps

Operational playbook for the GalaxyServe service running on the GalaxyOps platform.
Every alert defined in [`monitoring/alerts/slo.yaml`](../monitoring/alerts/slo.yaml) maps to
an entry here: **symptom → diagnosis → action**.

---

## Accessing the platform UIs

ArgoCD, Grafana, Prometheus, and Alertmanager are not exposed via ingress by default
(local-only). Port-forward them:

```bash
# ArgoCD UI  → https://localhost:8085   (user: admin)
kubectl -n argocd port-forward svc/argocd-server 8085:443
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d ; echo

# Grafana    → http://localhost:3000    (user: admin / prom-operator)
kubectl -n monitoring port-forward svc/kps-grafana 3000:80

# Prometheus → http://localhost:9090
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090

# Alertmanager → http://localhost:9093
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-alertmanager 9093:9093
```

---

## Quick triage

```bash
# Is the app healthy?
kubectl -n galaxyserve get pods,hpa,pdb
kubectl -n galaxyserve describe deploy galaxyserve | sed -n '/Conditions/,/Events/p'

# Is GitOps in sync?
kubectl -n argocd get applications

# Recent events (sorted)
kubectl -n galaxyserve get events --sort-by=.lastTimestamp | tail -20

# Logs (last 5 min, all replicas)
kubectl -n galaxyserve logs -l app.kubernetes.io/name=galaxyserve --since=5m --prefix
```

---

## Alert: `GalaxyServeErrorBudgetBurnFast` (PAGE)

**Symptom:** 5xx error rate is burning the 30-day error budget ~14× too fast (confirmed over
1h + 5m windows). At this rate the monthly budget is gone in ~2 days.

**Diagnose:**
1. `kubectl -n galaxyserve get pods` — are pods crashing or `Running`?
2. Grafana → *GalaxyServe Overview* → "Error rate by status / endpoint". Which endpoint?
3. `kubectl -n galaxyserve logs -l app.kubernetes.io/name=galaxyserve --since=10m | grep -iE 'error|trace|exception'`
4. Recent deploy? `kubectl -n argocd get application galaxyserve -o jsonpath='{.status.sync.revision}'`

**Act:**
- **If a recent rollout caused it** → roll back: `kubectl -n galaxyserve rollout undo deploy/galaxyserve`
  (or revert the tag bump commit; ArgoCD will sync the previous good tag).
- **If model failed to load** (`/health` 503, `galaxyserve_model_loaded == 0`) → check weights
  mount / MLflow registry connectivity (see "Model not loaded" below).
- **If a dependency is down** → check NetworkPolicy isn't blocking egress; check MLflow pod.
- Once stable, confirm the burn-rate alert clears within ~1h.

---

## Alert: `GalaxyServeErrorBudgetBurnSlow` (PAGE)

**Symptom:** Sustained ~6× burn over 6h + 30m windows. Not an acute outage but a steady leak.

**Diagnose / Act:** Same surfaces as the fast burn, but look for *intermittent* failures —
a flaky downstream, occasional OOMKills (`kubectl -n galaxyserve get pods -o wide` →
`RESTARTS`), or one bad replica. Drain/cordon a bad node if isolated.

---

## Alert: `GalaxyServeHighLatency`

**Symptom:** p95 latency on `/predict` exceeds the 500ms SLO.

**Diagnose:**
1. Grafana → latency panel: is it p95 only, or p50 too (broad slowdown)?
2. `kubectl -n galaxyserve get hpa galaxyserve` — is it pinned at max replicas? CPU saturated?
3. `kubectl -n galaxyserve top pods` — CPU/memory pressure?

**Act:**
- **CPU-bound at HPA max** → raise `autoscaling.maxReplicas` (Helm value) or the per-pod CPU
  limit; commit + push → ArgoCD rolls it out.
- **Cold model / GC pauses** → check `galaxyserve_inference_duration_seconds`.
- Latency is the leading indicator of the availability SLO — treat persistent breaches seriously.

---

## Alert: `GalaxyServeCrashLooping`

**Symptom:** A pod's restart count is climbing (CrashLoopBackOff).

**Diagnose:**
```bash
kubectl -n galaxyserve get pods
kubectl -n galaxyserve logs <pod> --previous          # logs from the crashed instance
kubectl -n galaxyserve describe pod <pod> | sed -n '/Last State/,/Events/p'
```
Common causes: bad image tag, missing weights → liveness probe failing, OOMKilled
(bump memory limit), or a config/env error.

**Act:** Fix the root cause in the Helm values or image and let ArgoCD redeploy. If a bad
tag was promoted, revert the CI tag-bump commit.

---

## Alert: `GalaxyServeAbsent`

**Symptom:** Prometheus has no scrape target for GalaxyServe — service is gone or unscrapeable.

**Diagnose:** `kubectl -n galaxyserve get pods,svc,servicemonitor`. Check the ServiceMonitor
selector matches the Service labels and the `/metrics` port is named correctly.

**Act:** If the Deployment is scaled to 0 or the namespace was deleted, resync ArgoCD:
`argocd app sync galaxyserve` (or `kubectl -n argocd patch ...`). Verify self-heal is enabled.

---

## Common operations

### Model not loaded (`/health` returns 503)

GalaxyServe reports `unavailable` until a model is loaded. Either:
- mount weights (`values.yaml → galaxyserve.weights.enabled=true`, provide the PVC/path), or
- enable the registry (`galaxyserve.registry.enabled=true`, set `mlflowTrackingUri`).

Check: `kubectl -n galaxyserve exec deploy/galaxyserve -- env | grep GALAXYSERVE_`

### Force a GitOps resync / verify self-heal

```bash
# Drift test: hand-edit, watch ArgoCD revert it
kubectl -n galaxyserve scale deploy/galaxyserve --replicas=5
kubectl -n argocd get application galaxyserve -w     # OutOfSync → Synced, replicas revert
```

### Rolling restart (no downtime)

```bash
kubectl -n galaxyserve rollout restart deploy/galaxyserve
kubectl -n galaxyserve rollout status deploy/galaxyserve
```

### Manual scale ceiling during an incident

```bash
# Temporary; ArgoCD will revert unless you also commit the value.
kubectl -n galaxyserve patch hpa galaxyserve --type merge -p '{"spec":{"maxReplicas":15}}'
```

---

## Chaos drill (recovery validation)

```bash
chaos/experiments/pod-kill.sh galaxyserve 5     # kill a pod every 5s
# In Grafana, watch: pod count dip + recover, SLO availability stays ≥ 99.9%.
```
Expected: Deployment recreates the pod, the PDB prevents over-eviction, and the readiness
probe keeps traffic off pods until the model is loaded → no user-visible errors.
