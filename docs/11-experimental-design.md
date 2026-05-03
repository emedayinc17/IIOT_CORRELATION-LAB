# 11 — Diseño experimental

## Enfoque

El laboratorio adopta un diseño controlado, reproducible y no destructivo.

Prioridades:

- estabilidad del entorno;
- trazabilidad por ejecución;
- datasets comparables;
- evidencia reproducible;
- análisis estadístico prudente;
- separación entre ataques y ruido legítimo.

## Escenario D

Escenario D evalúa detección y correlación bajo ataques controlados MITRE ATT&CK for ICS.

Parámetros recomendados:

| Parámetro | Valor |
|---|---:|
| iteraciones por técnica | 20 |
| técnicas | T0809, T0814, T0860 |
| ventana correlación | 120s |
| lookback/forward Zabbix | 120s / 120s |

## Escenario E

Escenario E evalúa falsos positivos bajo ruido operacional legítimo.

Parámetros recomendados:

| Parámetro | Valor |
|---|---:|
| perfiles | LOW, MEDIUM, HIGH |
| iteraciones por perfil | 20 |
| duración por iteración | 30s |
| cooldown | 10s |
| endpoints HTTP | rutas saludables 200 |
| MQTT | publicaciones legítimas |

## Justificación del Escenario E

Escenario E responde a preocupaciones sobre:

- falsos positivos;
- variabilidad operacional;
- robustez;
- realismo IIoT;
- separación ataque/ruido.

No es un benchmark de performance ni un escenario de sabotaje.

## Estadística

Se reportan:

- tasas;
- Wilson CI 95%;
- percentiles;
- bootstrap CI cuando aplica.

## Limitación del estudio

Los ataques y ruidos son controlados. El estudio no maximiza degradación destructiva ni simula todos los posibles comportamientos industriales reales.
