# 15 — Discusión y limitaciones

## Contribución principal

El laboratorio demuestra que una capa integrada Zabbix + Wazuh puede soportar correlación temporal basada en eventos entre métricas operacionales y eventos de seguridad en un entorno IIoT controlado.

## Contribución de robustez

El Escenario E fortalece el diseño experimental al introducir variabilidad operacional legítima y medir falsos positivos. Esto evita limitar el trabajo a una demostración de detección ante ataques.

## Límites de interpretación

- El entorno es un laboratorio MicroK8s controlado, no una red minera productiva.
- Los ataques son simulaciones controladas.
- El despliegue Wazuh es single-node por reproducibilidad.
- La correlación es temporal y basada en eventos.
- El resultado FPR debe reportarse con intervalo Wilson.

## Claim recomendado

Se puede afirmar:

> El laboratorio mostró alineamiento temporal consistente entre eventos de seguridad controlados y métricas operacionales, y no produjo falsos positivos MITRE-equivalentes bajo los perfiles de ruido operacional legítimo evaluados.

No afirmar:

> El sistema garantiza cero falsos positivos.
> El sistema reduce MTTD en producción.
> La arquitectura generaliza directamente a cualquier red industrial.
