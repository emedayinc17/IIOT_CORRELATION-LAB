# 06 — Wazuh Security

## Propósito del Escenario C

El Escenario C incorpora Wazuh como capa de observabilidad de seguridad sobre la base ya congelada del laboratorio: Foundation IIoT y Zabbix. El objetivo no es evaluar seguridad de Kubernetes, hardening Linux, alta disponibilidad SIEM ni escalabilidad enterprise.

El objetivo metodológico es habilitar una fuente reproducible de eventos de seguridad estructurados para su posterior correlación con métricas operacionales de Zabbix en el Escenario D.

## Decisión metodológica

Se adopta un despliegue Wazuh single-node/all-in-one dentro del namespace `security`. Esta decisión reduce variables experimentales, simplifica la reproducibilidad y evita introducir complejidad de alta disponibilidad o clustering que no aporta directamente a la hipótesis del paper.

La hipótesis experimental se centra en la correlación operacional-seguridad en un entorno IIoT controlado. Por ello, el diseño prioriza:

- control experimental;
- trazabilidad;
- persistencia;
- congelamiento de evidencias;
- timestamps comparables;
- datasets reproducibles.

## Entorno real validado

El despliegue de Wazuh se ajusta al entorno real del laboratorio:

| Elemento | Valor |
|---|---|
| Kubernetes | MicroK8s |
| Versión | v1.30.x |
| Nodo | single-node |
| Sistema operativo | Ubuntu 24.04 |
| Runtime | containerd |
| CNI | Calico |
| LoadBalancer | MetalLB |
| StorageClass | `microk8s-hostpath` |
| Namespace Wazuh | `security` |

Kubernetes se utiliza únicamente como medio reproducible de despliegue. La infraestructura Kubernetes no es el objeto de estudio.

## Componentes

| Componente | Namespace | Propósito |
|---|---|---|
| Wazuh Manager | `security` | recepción, normalización y evaluación de eventos |
| Wazuh Indexer | `security` | persistencia/indexación de eventos y alertas |
| Wazuh Dashboard | `security` | interfaz de revisión y validación visual |
| Reglas IIoT/MITRE ICS | `security` | mapeo de eventos del laboratorio hacia técnicas ICS |
| Localfile baseline | `security` | archivo JSON estructurado para eventos de Escenario C |

## Endpoints del laboratorio

| Servicio | IP | Puerto | Uso |
|---|---:|---:|---|
| Wazuh Dashboard | `10.10.0.161` | `443` | validación visual |
| Wazuh Manager | `10.10.0.162` | `1514/1515/55000` | manager/API/agentes |

## Manifiestos incorporados

Los manifiestos incrementales propios del laboratorio se ubican únicamente en `kubernetes/security/`:

```text
kubernetes/security/
  00-namespace.yaml
  01-wazuh-methodology.yaml
  02-wazuh-iiot-rules.yaml
  03-wazuh-services.yaml
  04-scenario-c-event-schema.yaml
  kustomization.yaml
```

El archivo `kubernetes/security/05-wazuh-dashboard-indexer-credentials-note.yaml` no forma parte del flujo reproducible final del Escenario C. Fue una nota metodológica temporal generada durante la depuración del dashboard y puede retirarse del repositorio oficial. La explicación técnica ya queda consolidada en este documento.

## Despliegue reproducible

El despliegue y reconciliación de Wazuh se controla desde:

```text
scripts/run/11-deploy-wazuh-security.sh
```

El script valida el perfil real del laboratorio, aplica los manifiestos incrementales, reutiliza el namespace `security`, valida PVCs, espera los workloads, conserva el modelo single-node/all-in-one y evita introducir herramientas fuera del alcance del paper.

Cuando Wazuh ya existe, el script ejecuta reconciliación correctiva sin `git clone` en tiempo de ejecución y sin redeploy destructivo. Esta estrategia permite repetir el script de forma idempotente durante validaciones del jurado o revisiones internas.

## Reconciliación Dashboard → Wazuh API

Durante la estabilización del Escenario C se identificó que el Dashboard podía quedar accesible externamente, pero con la conexión interna a la API del Wazuh Manager en estado `Offline` si el archivo interno `wazuh.yml` conservaba valores por defecto.

La corrección reproducible queda integrada en `scripts/run/11-deploy-wazuh-security.sh` y consiste en:

1. leer credenciales reales desde `secret/wazuh-api-cred`;
2. validar autenticación real contra la API del Wazuh Manager;
3. configurar el Dashboard contra el FQDN Kubernetes completo del manager;
4. reiniciar únicamente `deployment/wazuh-dashboard`;
5. validar que el Dashboard pueda autenticarse contra la API.

La URL interna estabilizada es:

```text
https://wazuh.security.svc.cluster.local:55000
```

Esta decisión evita ambigüedad DNS y mejora reproducibilidad dentro de MicroK8s. No modifica la arquitectura, no introduce nuevos componentes y no desplaza el foco hacia seguridad de Kubernetes.

## Reconciliación Dashboard → Indexer

El Dashboard también requiere credenciales válidas para comunicarse con Wazuh Indexer. En el despliegue local de Wazuh, las credenciales reales del indexer se mantienen en `secret/indexer-cred` y son inyectadas en el deployment del Dashboard mediante variables de entorno:

```text
OPENSEARCH_HOSTS=https://wazuh-indexer:9200
OPENSEARCH_USERNAME=<secret/indexer-cred.username>
OPENSEARCH_PASSWORD=<secret/indexer-cred.password>
```

La existencia de `secret/wazuh-indexer-credentials` puede mantenerse como alias de compatibilidad si fue creado durante la reconciliación, pero no es un manifiesto adicional requerido por el flujo final del laboratorio. La configuración efectiva y reproducible queda controlada por el deployment y por los scripts `11` y `12`.

## Reglas IIoT/MITRE ICS

El script `11-deploy-wazuh-security.sh` reinstala las reglas locales después del readiness del Wazuh Manager, con permisos controlados, para evitar condiciones de carrera durante el bootstrap del contenedor.

El archivo lógico instalado en el manager es:

```text
/var/ossec/etc/rules/iiot_local_rules.xml
```

El warning observado en contenedor sobre límites de file descriptors (`Could not set resource limit... Operation not permitted`) no afecta el objetivo experimental mientras los servicios Wazuh se encuentren activos y las reglas sean legibles por `wazuh-analysisd`.

## Eventos estructurados

El baseline de seguridad escribe eventos JSON en el Wazuh Manager mediante un `localfile` controlado:

```text
/var/ossec/logs/iiot-lab/scenario_c_baseline.json
```

Cada evento contiene como mínimo:

| Campo | Descripción |
|---|---|
| `timestamp_utc` | timestamp UTC comparable con Zabbix y collectors |
| `scenario` | identificador del escenario experimental |
| `source_namespace` | namespace origen del servicio IIoT |
| `component` | componente observado |
| `event_type` | tipo de evento |
| `iiot_lab.attack_id` | técnica MITRE ICS o `NONE` para baseline |
| `iiot_lab.asset` | activo lógico observado |
| `iiot_lab.zone` | zona lógica del laboratorio |

## Técnicas MITRE ATT&CK for ICS preparadas

| Técnica | Uso en laboratorio | Momento de evaluación |
|---|---|---|
| T0809 | comando no autorizado vía MQTT | Escenario D |
| T0814 | manipulación de telemetría | Escenario D |
| T0860 | degradación/DoS HTTP | Escenario D |
| NONE | baseline de seguridad sin ataque | Escenario C |

## Validación

La validación del Escenario C se controla desde:

```text
scripts/run/12-validate-wazuh-security.sh
```

El script debe confirmar:

```text
[OK] MicroK8s single-node validado
[OK] StorageClass microk8s-hostpath validada
[OK] PVCs Wazuh Bound
[OK] Sin errores ImagePullBackOff/ErrImagePull
[OK] Sin worker Wazuh adicional: modelo single-node/all-in-one preservado
[OK] Wazuh Indexer listo
[OK] Wazuh Manager master listo
[OK] Wazuh Dashboard listo
[OK] Dashboard responde en https://10.10.0.161
[OK] Puerto Wazuh API 55000 accesible en 10.10.0.162
[OK] Dashboard puede autenticarse contra Wazuh Manager API
[OK] Reglas IIoT/MITRE ICS instaladas en Wazuh Manager
[OK] Localfile de baseline IIoT configurado
```

## Scripts asociados

```text
scripts/run/11-deploy-wazuh-security.sh
scripts/run/12-validate-wazuh-security.sh
scripts/run/13-run-wazuh-security-baseline.sh
scripts/run/14-freeze-wazuh-security-baseline.sh
```

## Evidencias generadas

```text
evidence/wazuh/
results/raw/scenario_c/wazuh_security_baseline.csv
baseline/scenario_c_wazuh_security/
kubernetes/security/wazuh-frozen/
```

El freeze del Escenario C genera checksums, snapshot del namespace `security`, PVCs, servicios, ConfigMaps y manifiestos congelados del despliegue Wazuh validado.

## Exclusiones explícitas

No forman parte del Escenario C:

- Falco;
- CIS benchmark;
- runtime security;
- hardening Kubernetes;
- auditd de host Linux;
- clustering Wazuh HA;
- evaluación de performance SIEM distribuida;
- Prometheus, Grafana, Loki o service mesh.

Estas exclusiones reducen variables no relacionadas con el objetivo del paper y preservan el foco:

```text
IIoT + Zabbix + Wazuh + correlación
```

## Estado metodológico del Escenario C

Con el despliegue, baseline y freeze completados, el Escenario C queda cerrado como baseline de seguridad reproducible. Su función es preparar la fuente de eventos Wazuh para el Escenario D, donde se ejecutarán ataques MITRE ICS controlados y se correlacionarán eventos de seguridad con impacto operacional observado por Zabbix.
