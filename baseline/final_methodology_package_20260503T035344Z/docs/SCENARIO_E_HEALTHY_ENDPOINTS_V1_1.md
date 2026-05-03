# Scenario E v1.1 — Healthy Operational Noise

This incremental update corrects Scenario E HTTP noise generation to use only validated healthy endpoints:

- `http://10.10.0.152:8080/health`
- `http://10.10.0.153:8080/health`
- `http://10.10.0.153:8080/metrics`
- `http://10.10.0.153:8080/telemetry`
- `http://10.10.0.154:8080/health`

The script validates all endpoints before starting the campaign and fails fast if any endpoint does not return HTTP 200.

This avoids artificial HTTP errors caused by root paths returning 404/000 and keeps Scenario E aligned with its purpose: legitimate operational noise and FPR estimation.
