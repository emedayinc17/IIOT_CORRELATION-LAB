# Scenario readiness summary

- Generated UTC: `2026-05-03T04:04:02Z`
- Overall status: `OK`

| Scenario | Role | Status | Notes |
|---|---|---|---|
| A | Functional foundation | OK | A is a construction/functional validation scenario, not a statistical campaign. |
| B | Operational instrumentation | OK | B validates monitoring instrumentation; quantitative attack analysis is performed in D. |
| C | Security instrumentation | OK | C validates security instrumentation; attack campaign evidence is produced in D. |
| D | Quantitative attack/correlation campaign | OK | D is the main attack detection and event-based temporal correlation campaign. |
| E | Quantitative operational-noise/FPR control campaign | OK | E is the false-positive control campaign under legitimate operational variability. |

## Zabbix export evidence

- `baseline/final_methodology_package_20260503T035344Z/evidence/zabbix/zabbix_configuration_summary.md`
- `baseline/final_methodology_package_20260503T035344Z/evidence/zabbix/zabbix_hostgroups.json`
- `baseline/final_methodology_package_20260503T035344Z/evidence/zabbix/zabbix_hosts.json`
- `baseline/final_methodology_package_20260503T035344Z/evidence/zabbix/zabbix_items.json`
- `baseline/final_methodology_package_20260503T035344Z/evidence/zabbix/zabbix_triggers.json`
- `baseline/final_methodology_package_20260503T035344Z/evidence/zabbix/zabbix-zabbix-hosts-real-monitoring.json`
- `baseline/final_methodology_package_20260503T035344Z/evidence/zabbix/zabbix-zabbix-items-real-monitoring.json`
- `baseline/final_methodology_package_20260503T035344Z/evidence/zabbix/zabbix-zabbix-real-monitoring-summary.csv`
- `baseline/final_methodology_package_20260503T035344Z/evidence/zabbix/zabbix-zabbix-triggers-real-monitoring.json`
- `baseline/scenario_B_20260502_033417/zabbix_hosts.json`
- `baseline/scenario_B_20260502_033417/zabbix_items.json`
- `baseline/scenario_B_20260502_033417/zabbix_triggers.json`
- `evidence/zabbix/zabbix_configuration_summary.md`
- `evidence/zabbix/zabbix_hostgroups.json`
- `evidence/zabbix/zabbix_hosts.json`
- `evidence/zabbix/zabbix_items.json`
- `evidence/zabbix/zabbix_triggers.json`
- `evidence/zabbix/zabbix-zabbix-hosts-real-monitoring.json`
- `evidence/zabbix/zabbix-zabbix-items-real-monitoring.json`
- `evidence/zabbix/zabbix-zabbix-real-monitoring-summary.csv`
- `evidence/zabbix/zabbix-zabbix-triggers-real-monitoring.json`

## Methodological interpretation

A–C are construction/instrumentation validation scenarios. D and E are the quantitative campaigns used for statistical analysis.
