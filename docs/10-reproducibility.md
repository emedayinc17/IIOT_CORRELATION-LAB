## Nota de corrección v1.2 — análisis temporal robusto

La capa 21–22 ahora maneja de forma explícita tres escenarios:

1. deltas temporales por ejecución disponibles;
2. fallback agregado desde `table_correlation_latency.csv`;
3. ausencia de delta temporal, en cuyo caso se generan tablas explícitas sin fallar silenciosamente.

Esto evita errores por listas vacías y deja trazabilidad del origen del delta en:

```text
results/processed/temporal_correlation_diagnostics.json
```


<!-- SCENARIO_E_NOISE_FPR_V1 -->

## Scenario E reproducibility

Scenario E is reproduced with scripts 23–25. The freeze includes raw noise datasets, processed FPR datasets, tables, evidence, Kubernetes snapshots, scripts, and SHA256SUMS.

