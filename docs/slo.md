# Service Level Objectives — GalaxyServe on GalaxyOps

This document defines the SLIs, SLOs, and error budget for the GalaxyServe inference
service, and explains the burn-rate alerting strategy implemented in
[`monitoring/alerts/slo.yaml`](../monitoring/alerts/slo.yaml).

## Service Level Indicators (SLIs)

All SLIs are derived from the Prometheus metrics GalaxyServe exposes on `/metrics`:

| SLI | Definition | Source metric |
|---|---|---|
| **Availability** | fraction of HTTP requests that did *not* return 5xx | `galaxyserve_requests_total{status=~"5.."}` / `galaxyserve_requests_total` |
| **Latency** | fraction of `/predict` requests served under 500ms | `galaxyserve_request_latency_seconds_bucket{endpoint="/predict"}` |

We measure availability and latency as **good-event / valid-event** ratios — the standard
SRE formulation — rather than raw uptime, because a service can be "up" while serving errors.

## Service Level Objectives (SLOs)

| SLO | Target | Window |
|---|---|---|
| Availability | **99.9%** of requests non-5xx | rolling 30 days |
| Latency | **95%** of `/predict` under **500ms** | rolling 30 days |

### Error budget

A 99.9% availability SLO over 30 days permits **43.2 minutes** of "down" (full-error)
equivalent per month:

```
error budget = (1 - 0.999) × 30 days = 0.001 × 43,200 min = 43.2 min
```

The error budget is what we are *allowed* to spend on failed requests. When it is being
consumed too fast, we alert; when it is exhausted, the policy is to freeze risky changes
and prioritize reliability work over features.

## Burn-rate alerting

Rather than page on every brief blip, we use **multi-window, multi-burn-rate** alerts
(the Google SRE workbook pattern). Burn rate = how fast we are consuming the error budget
relative to the rate that would exactly exhaust it over the SLO window.

| Severity | Burn rate | Long window | Short window | Budget consumed | Meaning |
|---|---|---|---|---|---|
| **Page (fast)** | 14.4× | 1h | 5m | ~2% in 1h | Acute outage — wake someone |
| **Page (slow)** | 6× | 6h | 30m | ~5% in 6h | Sustained degradation |
| **Ticket** | 1× | 24h | — | steady slow burn | Investigate during work hours |

The short window guards against the long window being slow to recover after an incident
ends (it prevents the alert from flapping/re-firing). Both windows must be burning for the
alert to fire.

Example PromQL for the fast-burn availability alert (14.4× over 1h, confirmed by 5m):

```promql
(
  sum(rate(galaxyserve_requests_total{status=~"5.."}[1h]))
  / sum(rate(galaxyserve_requests_total[1h]))
) > (14.4 * 0.001)
and
(
  sum(rate(galaxyserve_requests_total{status=~"5.."}[5m]))
  / sum(rate(galaxyserve_requests_total[5m]))
) > (14.4 * 0.001)
```

`0.001` is `(1 - SLO)` for the 99.9% availability target.

## What each alert maps to

See [`docs/runbook.md`](runbook.md) for the operational response to each alert:

- `GalaxyServeErrorBudgetBurnFast` → page, suspected outage
- `GalaxyServeErrorBudgetBurnSlow` → page, sustained degradation
- `GalaxyServeHighLatency` → latency SLO at risk
- `GalaxyServeCrashLooping` → pod stability
- `GalaxyServeAbsent` → scrape target gone / service down

## Reviewing the SLO

SLO targets are a contract, not a constant. Review quarterly:

- If we consistently beat 99.9% with budget to spare, the target may be too loose (ship faster).
- If we routinely burn the budget, either invest in reliability or renegotiate the target with stakeholders.
