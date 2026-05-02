# 13 — Reviewer Traceability

## Objetivo

Relacionar observaciones de revisión con evidencias concretas del laboratorio.

## Matriz de trazabilidad

| Observación | Evidencia generada |
|---|---|
| Especificar Kubernetes specs | `docs/02-environment.md`, `evidence/inventory/version_matrix.md` |
| Documentar arquitectura | `docs/01-architecture.md` |
| Proveer scripts/configs | `scripts/run/`, `kubernetes/` |
| Proveer versiones | `docs/12-version-matrix.md`, `evidence/inventory/` |
| Justificar configuración experimental | `docs/11-experimental-design.md` |
| Documentar workflow reproducible | `docs/08-experiments.md`, `docs/10-reproducibility.md` |
| Diferenciar simulado vs real | `docs/11-experimental-design.md` |
| Evidenciar monitoreo Zabbix | `evidence/zabbix/`, `baseline/scenario_B_*` |
| Congelar escenarios | `baseline/scenario_A_*`, `baseline/scenario_B_*` |

## Estado previo a Wazuh

Antes de iniciar Escenario C, el laboratorio debe tener:

- Escenario A congelado.
- Escenario B congelado.
- inventario exportado.
- configuración Zabbix exportada.
- matriz de versiones generada.
- diseño experimental documentado.


## Trazabilidad agregada — Escenario C

| Observación | Evidencia generada |
|---|---|
| Documentar capa de seguridad | `docs/06-wazuh-security.md` |
| Justificar Wazuh single-node | `docs/11-experimental-design.md` |
| Evitar scope creep Kubernetes security | `docs/06-wazuh-security.md`, `docs/11-experimental-design.md` |
| Proveer scripts automatizados Wazuh | `scripts/run/11-*.sh` a `14-*.sh` |
| Proveer manifiestos reproducibles | `kubernetes/security/`, `kubernetes/security/` |
| Evidenciar validación de Wazuh | `evidence/wazuh/*-wazuh-validation-summary.csv` |
| Evidenciar baseline de seguridad | `results/raw/scenario_c/wazuh_security_baseline.csv` |
| Congelar Escenario C | `baseline/scenario_c_wazuh_security/` |
| Mantener diferenciación real vs simulado | `docs/11-experimental-design.md` |

## Estado esperado después de Escenario C

- Escenario A congelado.
- Escenario B congelado.
- Zabbix operativo y exportado.
- Wazuh operativo en namespace `security`.
- Eventos de baseline de seguridad generados.
- Freeze reproducible de Escenario C disponible.
- Laboratorio listo para Escenario D con ataques MITRE ATT&CK for ICS y correlación.

<!-- SCENARIO_D_INCREMENTAL_V1 -->
## Trazabilidad del Escenario D frente a revisores

| Observación esperada | Evidencia generada |
|---|---|
| Reproducibilidad experimental | scripts `15` a `18`, freeze con SHA256SUMS |
| Diferenciación real/simulado | ataques controlados documentados por técnica MITRE ICS |
| Workflow completo | A/B/C congelados + D correlacionado |
| Evidencia cuantitativa | CSV raw, processed y tables |
| Evidencia visual | figuras SVG reproducibles |
| No scope creep | sin Falco, sin hardening Kubernetes, sin HA Wazuh |

El Escenario D permite defender que el laboratorio no solo despliega herramientas, sino que produce evidencia experimental correlacionada para el objetivo del paper.
