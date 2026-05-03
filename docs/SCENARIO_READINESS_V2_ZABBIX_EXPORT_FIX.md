# Scenario readiness v2 — Zabbix export evidence fix

This update corrects the readiness validator so it recognizes the actual Zabbix export files present in the project.

Detected evidence patterns include:

- `evidence/zabbix/zabbix_configuration_summary.md`
- `evidence/zabbix/zabbix_hostgroups.json`
- `evidence/zabbix/zabbix_hosts.json`
- `evidence/zabbix/zabbix_items.json`
- `evidence/zabbix/zabbix_triggers.json`
- `evidence/zabbix/zabbix-zabbix-hosts-real-monitoring.json`
- `evidence/zabbix/zabbix-zabbix-items-real-monitoring.json`
- `evidence/zabbix/zabbix-zabbix-triggers-real-monitoring.json`
- `evidence/zabbix/zabbix-zabbix-real-monitoring-summary.csv`

The previous readiness message `zabbix config export not found in default names` was a false negative caused by restrictive filename detection.
