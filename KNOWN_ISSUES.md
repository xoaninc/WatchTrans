# Known Issues

## ~~StopAlertBadge shows on all Renfe stations~~ ✅ RESUELTO

`StopAlertBadge` se eliminó. Las alertas por parada ahora se filtran usando `AlertFilterHelper.alertsForStop()`, que solo muestra alertas con stop-level entities (entidades con `stop_id` específico). Esto evita que alertas genéricas de ruta aparezcan en todas las paradas. Implementado en iOS y watchOS `LineDetailView`.

Además, alertas `FULL_SUSPENSION` con stop-level entities ahora se tratan como suspensión parcial (no marcan toda la línea como cerrada).

## ~~API field renames not propagated to app models~~ ✅ RESUELTO

Updated CodingKeys to map the new API field names (commits `6314089`, `e793039`).

## ~~Equipment status de Metro Sevilla: ubicación y estandarización~~ ✅ RESUELTO

Extraído a componente genérico `EquipmentStatusSection.swift` con iconos AIGA, círculos verde/rojo, equipos fuera de servicio primero.

## ~~Líneas no cargadas hasta entrar en sección Líneas~~ ✅ RESUELTO

`fetchTransportData` ahora llama `fetchLinesIfNeeded` automáticamente al arrancar.

## parkingBicis se usa como parking genérico

El campo `parkingBicis` de la API se mapea a `hasParking` en el modelo `Stop`, que muestra un badge "Parking" genérico con icono `p.circle.fill`. No distingue entre parking de coches y parking de bicis. No hay badge específico de parking de bicis.

## LineResponse: CodingKeys desactualizados

La API ahora manda `route_color` y `route_text_color` en `LineResponse`, pero nuestro modelo usa `color` y `textColor` como CodingKeys. Puede causar que los colores de línea no se decodifiquen.

**Archivos afectados:** `WatchTransModels.swift` (ambos targets), struct `LineResponse`.

## DepartureResponse: campos nuevos no consumidos

La API ahora envía campos que la app no decodifica. No causan errores (se ignoran silenciosamente) pero perdemos información útil:

| Campo | Para qué sirve |
|---|---|
| `platform_confidence` | Confianza de predicción de plataforma (0.0-1.0) |
| `delay_estimated` | Si el retraso es estimado vs confirmado |
| `is_express` / `express_name` / `express_color` | Trenes express (ej. CIVIS). Mostrar badge con `express_name` cuando `is_express: true` |
| `wheelchair_accessible_now` | Accesibilidad RT del tren (no solo estática) |
| `pmr_warning` | Aviso PMR (tren no accesible en esa parada) |
| `alternative_service_warning` | Aviso de servicio alternativo activo |
| `station_occupancy_pct` / `station_occupancy_status` | Ocupación de estación inline |
| `bearing` / `speed` (en train_position) | Rumbo y velocidad del tren |

**Prioridad:** `pmr_warning` y `is_express` son los más visibles para el usuario.

## AcercaService: falta campo `source`

El modelo `AcercaService` no decodifica `source` (ej. `"csv_renfe"`). No afecta la UI pero perdemos la trazabilidad del dato.

## Alertas: active_periods con fases temporales

La API ahora manda `effect` y `phase_description` dentro de cada `active_period`, permitiendo alertas multi-fase (ej. "servicio reducido hasta abril, luego corte total"). La app tiene el modelo `AlternativeTransport` pero no decodifica las fases de `active_periods`.

**Impacto:** Para alertas como la C3 Sevilla (parcial ahora, total en abril), no mostramos la evolución temporal.
