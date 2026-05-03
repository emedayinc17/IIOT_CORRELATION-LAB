# Scenario E v1.2 — Resilient execution

This update fixes a robustness issue observed during long paper-final runs.

## Problem fixed

The previous script appended benign Wazuh evidence via `kubectl exec` on every iteration. During long runs, a transient Wazuh container/pod state could interrupt the campaign with:

```text
unable to upgrade connection: container not found ("wazuh-manager")
```

## New behavior

- Generates benign Scenario E NDJSON locally during the campaign.
- Appends the full benign event batch to Wazuh once after all profiles finish.
- Retries the Wazuh append up to three times.
- Validates exact execution count before metadata.
- The freeze script refuses to freeze incomplete Scenario E runs.

## Paper-final rule

Only freeze Scenario E when:

```text
noise_events = 60
http_error_count = 0
false_positive analysis completed
```
