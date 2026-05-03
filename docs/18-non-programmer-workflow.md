# 18 - Flujo para revisores no programadores | Workflow for non-programmer reviewers

## Objetivo | Objective

Permitir que una persona no programadora ejecute o revise el laboratorio con comandos simples. | Allow a non-programmer to execute or review the laboratory with simple commands.

## Opción 1: revisar sin ejecutar campañas | Option 1: review without running campaigns

```bash
./scripts/run/30-validate-paper-readiness.sh
./scripts/run/31-show-paper-results.sh
./scripts/run/32-verify-final-freeze.sh
```

## Opción 2: ejecutar solo campañas finales D-E | Option 2: run only final campaigns D-E

```bash
./scripts/run/29-run-paper-final-campaign.sh
```

## Opción 3: ejecutar todo A-E | Option 3: run all A-E

```bash
./scripts/run/38-run-all-scenarios-ae.sh
```

## Qué debe revisar el revisor | What the reviewer should check

| Evidencia | Ruta |
|---|---|
| Detección MITRE | `results/tables/table_attack_detection.csv` |
| Correlación temporal | `results/tables/table_temporal_correlation_summary.csv` |
| MTTD/delta detección | `results/tables/table_mttd_estimation.csv` |
| FPR ruido operacional | `results/tables/table_noise_fpr_summary.csv` |
| Wilson IC95 FPR | `results/tables/table_noise_wilson_ci.csv` |
| Readiness A-E | `results/tables/table_scenario_readiness.csv` |
| Freeze final | `baseline/final_methodology_package_*` |
