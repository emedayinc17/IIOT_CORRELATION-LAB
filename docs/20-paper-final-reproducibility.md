# 20 - Reproducibilidad final para el artículo | Final reproducibility for the paper

## Propósito | Purpose

Este documento resume cómo el laboratorio sostiene la reproducibilidad metodológica exigida por los revisores. | This document summarizes how the laboratory supports the methodological reproducibility required by reviewers.

## Elementos reproducibles | Reproducible elements

| Elemento | Ruta |
|---|---|
| Parámetros experimentales | `config/experiment.conf` |
| Manifiestos Kubernetes | `kubernetes/` |
| Scripts técnicos | `scripts/run/00` a `scripts/run/28` |
| Scripts rápidos paper-ready | `scripts/run/29` a `scripts/run/38` |
| Datos crudos | `results/raw/` |
| Datos procesados | `results/processed/` |
| Tablas finales | `results/tables/` |
| Figuras | `results/figures/` |
| Evidencias | `evidence/` |
| Freezes | `baseline/` |

## Separación metodológica A-E | A-E methodological separation

Los escenarios A–C validan infraestructura e instrumentación. Los escenarios D–E contienen la evidencia cuantitativa principal del paper. | Scenarios A–C validate infrastructure and instrumentation. Scenarios D–E contain the main quantitative evidence for the paper.

## Criterio de integridad | Integrity criterion

El paquete final se considera íntegro cuando `scripts/run/32-verify-final-freeze.sh` valida correctamente `SHA256SUMS`. | The final package is considered integral when `scripts/run/32-verify-final-freeze.sh` successfully validates `SHA256SUMS`.
