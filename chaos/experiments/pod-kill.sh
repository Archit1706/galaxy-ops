#!/usr/bin/env bash
# Chaos experiment: repeatedly kill a random GalaxyServe pod and watch the
# Deployment self-heal. With the readiness probe + PodDisruptionBudget +
# maxUnavailable:0 rollout, traffic should stay green (SLO holds) throughout.
#
# Usage:
#   chaos/experiments/pod-kill.sh [namespace] [interval_seconds] [iterations]
#
# Example (kill a pod every 10s, 12 times = ~2 min):
#   chaos/experiments/pod-kill.sh galaxyserve 10 12
#
# Watch recovery in another terminal:
#   watch -n1 kubectl -n galaxyserve get pods
# And the SLO in Grafana (Availability stat should stay >= 99.9%).
set -euo pipefail

NS="${1:-galaxyserve}"
INTERVAL="${2:-10}"
ITERATIONS="${3:-12}"
SELECTOR="app.kubernetes.io/name=galaxyserve"

echo "Chaos: pod-kill on namespace=$NS every ${INTERVAL}s x ${ITERATIONS}"
echo "Selector: $SELECTOR"
echo

for i in $(seq 1 "$ITERATIONS"); do
  # Pick a random running pod.
  pod=$(kubectl -n "$NS" get pods -l "$SELECTOR" \
        --field-selector=status.phase=Running \
        -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | shuf | head -1 || true)

  if [[ -z "${pod}" ]]; then
    echo "[$i/$ITERATIONS] no running pod found; waiting..."
    sleep "$INTERVAL"
    continue
  fi

  ready=$(kubectl -n "$NS" get pods -l "$SELECTOR" \
          -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' \
          | grep -c True || true)
  echo "[$i/$ITERATIONS] killing pod '$pod' (ready replicas before: ${ready})"
  kubectl -n "$NS" delete pod "$pod" --grace-period=0 --force >/dev/null 2>&1 || true

  sleep "$INTERVAL"
done

echo
echo "Done. Final state:"
kubectl -n "$NS" get pods -l "$SELECTOR" -o wide
echo
echo "Verify: the Deployment recreated killed pods and stayed available."
echo "Check the SLO panel in Grafana over the experiment window."
