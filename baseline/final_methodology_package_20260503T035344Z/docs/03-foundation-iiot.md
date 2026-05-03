# 03 — Foundation IIoT

## Objetivo

Desplegar los servicios IIoT base del laboratorio y validar que el entorno mínimo funcione antes de introducir monitoreo, seguridad o ataques.

Esta capa representa el sistema operacional simulado sobre el cual se ejecutan los escenarios posteriores.

## Componentes

| Componente | Propósito |
|---|---|
| `mqtt-broker` | broker MQTT para telemetría |
| `sensor-simulator` | emisión de datos simulados |
| `health-app` | endpoint de salud operacional |
| `telemetry-api` | API de consulta de telemetría |
| `vulnerable-app` | servicio HTTP usado en pruebas controladas |

## Comandos

```bash
./scripts/run/00-reset-lab.sh
./scripts/run/01-deploy-foundation.sh
```

## Validaciones esperadas

Después del despliegue:

```bash
microk8s kubectl get all -n iiot-poc
microk8s kubectl get svc -n iiot-poc
```

Criterios:

```text
[OK] Namespace iiot-poc existe
[OK] Pods principales en Running
[OK] Servicios expuestos correctamente
[OK] Endpoints HTTP saludables responden
[OK] MQTT accesible para publicaciones legítimas
```

## Artefactos de salida

| Ruta | Descripción |
|---|---|
| `kubernetes/foundation/` | manifiestos declarativos |
| `results/raw/` | datasets base si aplica |
| `baseline/` | congelados del estado inicial |
| `evidence/inventory/` | inventario del laboratorio |

## Criterio de éxito

La Foundation IIoT se considera válida cuando los servicios base están disponibles y pueden ser usados por los escenarios B, C, D y E sin cambios adicionales de infraestructura.

## Errores comunes

| Síntoma | Posible causa | Acción |
|---|---|---|
| Pods en `ImagePullBackOff` | imagen no disponible o error de red | revisar imagen y conectividad |
| Services sin IP | MetalLB no asignó IP | validar MetalLB y rango configurado |
| HTTP no responde | ruta incorrecta o pod no listo | validar endpoint real con `curl` |
| MQTT no acepta conexión | broker no expuesto o puerto incorrecto | validar service y puerto 1883 |
