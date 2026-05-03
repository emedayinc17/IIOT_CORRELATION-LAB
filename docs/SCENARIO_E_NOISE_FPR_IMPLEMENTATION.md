# Scenario E — Operational Noise / False Positive Control

This incremental delivery adds Scenario E without modifying scenarios A–D.

Main scripts:

- `23-run-operational-noise-control.sh`
- `24-analyze-false-positive-rate.sh`
- `25-freeze-noise-control-results.sh`
- `26-apply-scenario-e-documentation-updates.sh`

Recommended paper-final parameters:

- LOW, MEDIUM, HIGH profiles
- 20 iterations per profile
- 30 seconds per iteration
- 10 seconds cooldown
- Wilson confidence interval for FPR

Run the documentation updater once after copying the files:

```bash
./scripts/run/26-apply-scenario-e-documentation-updates.sh
```
