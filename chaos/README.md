# Chaos experiments

Prove that GalaxyServe self-heals and holds its SLO under failure. Start with the
simple shell loop; graduate to Chaos Mesh for declarative, scheduled chaos.

## 1. Pod-kill loop (no extra tooling)

```bash
chaos/experiments/pod-kill.sh galaxyserve 10 12
```

Kills a random GalaxyServe pod every 10s, twelve times. In other terminals:

```bash
watch -n1 kubectl -n galaxyserve get pods          # see pods die and get recreated
# Grafana -> GalaxyServe Overview -> Availability stat should stay >= 99.9%
```

**Why it survives:** the readiness probe keeps traffic off pods until the model is
loaded, the PodDisruptionBudget refuses to let too many pods go at once, and the
`maxUnavailable: 0` rollout strategy means a replacement is Ready before anything
is removed. Net effect: no user-visible errors.

**Resume metric:** *"99.9% SLO held during pod-kill chaos; <15s recovery."*

## 2. Chaos Mesh (stretch — declarative)

Install Chaos Mesh (k3d uses containerd):

```bash
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm install chaos-mesh chaos-mesh/chaos-mesh -n chaos-mesh --create-namespace \
  --set chaosDaemon.runtime=containerd \
  --set chaosDaemon.socketPath=/run/k3s/containerd/containerd.sock
```

Then apply an experiment:

```bash
kubectl apply -f chaos/experiments/chaos-mesh-podkill.yaml        # scheduled pod kills
kubectl apply -f chaos/experiments/chaos-mesh-network-delay.yaml  # 100ms latency injection
```

The network-delay experiment is the one that exercises the **latency SLO** and
should trip the `GalaxyServeHighLatency` alert — a good demo of alerting working
end to end.

Clean up:

```bash
kubectl delete -f chaos/experiments/chaos-mesh-podkill.yaml
kubectl delete -f chaos/experiments/chaos-mesh-network-delay.yaml
```
