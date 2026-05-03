# 17 - Configuración y ejecución rápida | Configuration and quick execution

## Propósito | Purpose

Este documento describe la configuración central y la capa rápida de ejecución por escenario. | This document describes the central configuration and quick scenario execution layer.

## Configuración centralizada | Centralized configuration

```text
config/experiment.conf
```

Este archivo contiene repeticiones, técnicas MITRE, perfiles de ruido, ventanas temporales, parámetros de carga, endpoints y rutas de resultados. | This file contains repetitions, MITRE techniques, noise profiles, time windows, load parameters, endpoints, and result paths.

## Ejecución por escenario | Scenario execution

```bash
./scripts/run/33-run-scenario-a-foundation.sh
./scripts/run/34-run-scenario-b-zabbix.sh
./scripts/run/35-run-scenario-c-wazuh.sh
./scripts/run/36-run-scenario-d-correlation.sh
./scripts/run/37-run-scenario-e-noise-fpr.sh
```

## Ejecución completa A-E | Full A-E execution

```bash
./scripts/run/38-run-all-scenarios-ae.sh
```

## Campaña final D-E | Final D-E campaign

```bash
./scripts/run/29-run-paper-final-campaign.sh
```

## Validación y revisión | Validation and review

```bash
./scripts/run/30-validate-paper-readiness.sh
./scripts/run/31-show-paper-results.sh
./scripts/run/32-verify-final-freeze.sh
```

## Coherencia con el artículo | Manuscript coherence

Los valores de `config/experiment.conf` deben coincidir con metodología, resultados, tablas, discusión y respuesta a revisores. | Values in `config/experiment.conf` must match methodology, results, tables, discussion, and reviewer response.
