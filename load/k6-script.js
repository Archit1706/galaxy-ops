// k6 load test for GalaxyServe — drives the HPA and produces latency/error
// numbers for the resume ("p95 < 500ms while scaling 1->10 pods").
//
// Usage:
//   # full inference load (drives CPU -> HPA scale-out). Provide a galaxy image:
//   k6 run -e IMAGE=./galaxy.jpg -e BASE_URL=http://localhost:8080 load/k6-script.js
//
//   # lightweight smoke (no image needed; hits /health, lighter on CPU):
//   k6 run -e SCENARIO=health -e BASE_URL=http://localhost:8080 load/k6-script.js
//
// The ingress routes by Host header, so we send Host: galaxyserve.localhost.

import http from "k6/http";
import { check, sleep } from "k6";
import { Rate, Trend } from "k6/metrics";

const BASE_URL = __ENV.BASE_URL || "http://localhost:8080";
const HOST_HEADER = __ENV.HOST_HEADER || "galaxyserve.localhost";
const SCENARIO = __ENV.SCENARIO || "predict";
const IMAGE = __ENV.IMAGE || "";

// Load the image once at init time (shared across VUs) if provided.
const imageBin = IMAGE ? open(IMAGE, "b") : null;

const errorRate = new Rate("galaxyserve_errors");
const predictLatency = new Trend("predict_latency_ms", true);

export const options = {
  scenarios: {
    ramp: {
      executor: "ramping-vus",
      startVUs: 1,
      stages: [
        { duration: "1m", target: 10 }, // warm up
        { duration: "3m", target: 50 }, // climb — HPA should start adding pods
        { duration: "3m", target: 50 }, // hold at peak — watch it scale to max
        { duration: "1m", target: 0 }, // ramp down — watch it scale back in
      ],
      gracefulRampDown: "30s",
    },
  },
  thresholds: {
    // SLO-aligned gates: the run "fails" if we breach them.
    http_req_duration: ["p(95)<500"],
    galaxyserve_errors: ["rate<0.01"],
  },
};

const params = {
  headers: { Host: HOST_HEADER },
  tags: { name: SCENARIO },
};

export default function () {
  if (SCENARIO === "health") {
    const res = http.get(`${BASE_URL}/health`, params);
    check(res, { "health 200": (r) => r.status === 200 });
    errorRate.add(res.status >= 500);
    sleep(0.2);
    return;
  }

  if (!imageBin) {
    // No image supplied for the inference scenario — fall back to /ready so the
    // run still exercises the ingress path instead of erroring out.
    const res = http.get(`${BASE_URL}/ready`, params);
    check(res, { "ready reachable": (r) => r.status === 200 || r.status === 503 });
    sleep(0.3);
    return;
  }

  const payload = {
    file: http.file(imageBin, "galaxy.jpg", "image/jpeg"),
  };
  const res = http.post(`${BASE_URL}/predict`, payload, params);
  predictLatency.add(res.timings.duration);
  check(res, {
    "predict 200": (r) => r.status === 200,
    "has prediction": (r) => r.status === 200 && r.body && r.body.includes("label"),
  });
  errorRate.add(res.status >= 500);
  sleep(0.1);
}

export function handleSummary(data) {
  // Persist a JSON summary alongside the stdout report for the README metrics.
  return {
    stdout: textSummary(data),
    "load/results/summary.json": JSON.stringify(data, null, 2),
  };
}

// Minimal text summary (avoids importing the k6 jslib over the network).
function textSummary(data) {
  const m = data.metrics;
  const p95 = m.http_req_duration ? m.http_req_duration.values["p(95)"].toFixed(1) : "n/a";
  const reqs = m.http_reqs ? m.http_reqs.values.count : 0;
  const errs = m.galaxyserve_errors ? (m.galaxyserve_errors.values.rate * 100).toFixed(2) : "n/a";
  return (
    `\nGalaxyServe load summary\n` +
    `  total requests : ${reqs}\n` +
    `  p95 latency    : ${p95} ms\n` +
    `  error rate     : ${errs} %\n`
  );
}
