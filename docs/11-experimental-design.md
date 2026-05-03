## Corrección de trazabilidad v1.1

La campaña final se identifica mediante los `attack_uid` presentes en `results/raw/scenario_d/mitre_ics_attacks.csv`.

Todo análisis derivado debe filtrar eventos Wazuh, métricas Zabbix y correlaciones contra esa lista de identificadores. Esto evita contaminación por eventos históricos de corridas previas y mantiene trazabilidad uno-a-uno entre ejecución, evento y métrica.


<!-- SCENARIO_E_NOISE_FPR_V1 -->

## Methodological justification for Scenario E

Scenario E separates legitimate operational variability from attack behavior. It supports false-positive analysis and robustness evaluation without changing the main hypothesis or converting the study into a performance benchmark.

