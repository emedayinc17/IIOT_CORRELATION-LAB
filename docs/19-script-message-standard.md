# 19 - Estándar de mensajes y comentarios | Message and comment standard

## Objetivo | Objective

Mantener salidas compactas, bilingües y fáciles de revisar durante ejecución del laboratorio. | Keep outputs compact, bilingual, and easy to review during laboratory execution.

## Regla de mensajes | Message rule

Todo mensaje operativo debe estar en una sola línea con formato: | Every operational message must be one line using the format:

```text
español | English
```

Ejemplo: | Example:

```bash
echo "INFO: Validando Zabbix | Validating Zabbix"
```

## Regla de comentarios | Comment rule

Los comentarios funcionales en scripts deben ser bilingües y de una sola línea. | Functional script comments must be bilingual and one line.

```bash
# Carga configuración experimental | Loads experimental configuration
```

## Excepción | Exception

Las salidas extensas deben guardarse en `evidence/` o `results/raw/`, no imprimirse completas en pantalla. | Long outputs must be saved under `evidence/` or `results/raw/`, not fully printed on screen.
