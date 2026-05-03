# 12 — Version Matrix

## Objetivo

Registrar versiones de software, plataforma y componentes del laboratorio para garantizar reproducibilidad.

## Generación automática

```bash
./scripts/run/09-export-lab-inventory.sh
```

Salida:

```text
evidence/inventory/version_matrix.md
evidence/inventory/version_matrix.json
```


## Versiones adicionales para Escenario C

| Componente | Registro |
|---|---|
| Wazuh Kubernetes branch | `kubernetes/security/01-wazuh-methodology.yaml`, `wazuh-version-lock` |
| Namespace Wazuh | `security` |
| Deployment model | single-node/local laboratory deployment |
| Dashboard IP | `10.10.0.161` |
| Manager IP | `10.10.0.162` |

La versión real aplicada queda además registrada en `evidence/wazuh/*-wazuh-version-lock.yaml` luego de ejecutar `12-validate-wazuh-security.sh`.
