# Known Issues

## ~~StopAlertBadge shows on all Renfe stations~~ ✅ RESUELTO

`StopAlertBadge` se eliminó. Alertas por parada filtradas con `AlertFilterHelper`. Implementado en iOS y watchOS.

## ~~API field renames not propagated~~ ✅ RESUELTO

## ~~Equipment status de Metro Sevilla~~ ✅ RESUELTO

## ~~Líneas no cargadas hasta entrar en sección Líneas~~ ✅ RESUELTO

---

## ACTIVOS

### parkingBicis se usa como parking genérico

`parkingBicis` se mapea a `hasParking` → badge "Parking" genérico. No distingue parking de bicis de parking de coches. No hay badge específico de bicis.

### LineResponse: CodingKeys desactualizados

La API manda `route_color` y `route_text_color` en `LineResponse` y `LineRouteInfo`. Nuestros modelos:
- `LineResponse`: usa `color` y `textColor` como CodingKeys — **puede causar que colores no se decodifiquen**
- `LineRouteInfo`: usa `color` — debería ser `route_color`

**Archivos afectados:** `WatchTransModels.swift` (ambos targets), structs `LineResponse` y `LineRouteInfo`.

### DepartureResponse: campos nuevos no consumidos

La API envía campos que la app ignora silenciosamente:

| Campo | Para qué sirve | Prioridad |
|---|---|---|
| `is_express` / `express_name` / `express_color` | Trenes express CIVIS. Badge con `express_name` cuando `is_express: true` | **Alta** |
| `pmr_warning` | Alerta accesibilidad activa en la ruta → aviso PMR | **Alta** |
| `alternative_service_warning` | Servicio modificado/bus sustitución → aviso | **Alta** |
| `wheelchair_accessible_now` | Accesibilidad RT (false si hay alerta ACCESSIBILITY_ISSUE activa en la parada) | Media |
| `platform_confidence` | Confianza de predicción de andén (0.0-1.0) | Media |
| `delay_estimated` | Si el retraso se propagó del trip-level (no específico de esta parada) | Baja |
| `station_occupancy_pct` / `station_occupancy_status` | Ocupación de estación inline en departures (TMB) | Baja |
| `bearing` / `speed` (en train_position) | Rumbo y velocidad del tren | Baja |

### AcercaService: falta campo `source`

Modelo no decodifica `source` (ej. `"csv_renfe"`). No afecta UI pero pierde trazabilidad.

### Alertas: active_periods con fases temporales

La API manda `effect` y `phase_description` dentro de cada `active_period`, permitiendo alertas multi-fase (ej. C3: "reducido hasta abril, corte total después"). La app no decodifica estos campos de `active_periods`.

**Impacto:** Para alertas con evolución temporal, no mostramos las fases.

### Alertas: campo `severity_level` no mapeado

La API usa `severity_level` (ej. `"WARNING"`, `"SEVERE"`, `"INFO"`). Nuestro modelo tiene `severity` como CodingKey. Verificar si la API manda `severity` o `severity_level` — si es el segundo, la app no lo decodifica.

### TrainPositionResponse: faltan `bearing` y `speed`

La API manda `bearing` (rumbo 0-360°) y `speed` (km/h) en `train_position`. No los decodificamos. Útiles para orientar el icono del tren en el mapa.

### CompactDepartureResponse: no existe modelo

La API tiene `?compact=true` para departures que devuelve un esquema reducido (`line`, `color`, `dest`, `mins`, `plat`, `delay`, `exp`, `skip`, `alt_svc`, `occ_pct`, `occ_status`). No hay modelo `CompactDepartureResponse` en la app. Necesario para Widgets iOS y Siri Shortcuts.

### RouteOperatingHoursResponse: falta `source`

La API manda `source` (ej. `"stop_times"`) pero el modelo no lo tiene.

### PlatformPredictionResponse: faltan `observation_count` y `last_observed`

La API manda `observation_count` (245) y `last_observed` (timestamp) pero el modelo solo tiene `sampleSize` (que mapea a `sample_size`, no a `observation_count`). Verificar si `sample_size` y `observation_count` son el mismo campo renombrado.

### Euskotren IDs: trailing colon

Los stop_ids de Euskotren tienen `:` al final (ej. `EUSKOTREN_ES:Euskotren:StopPlace:1468:`). Si la app construye URLs con estos IDs sin URL-encode, las llamadas fallarán. Verificar que `URLComponents` maneja los colons correctamente.

### CIVIS como headsign

Si un tren tiene headsign `"CIVIS"`, la API lo descarta y usa la última parada en su lugar. Pero si la app recibe `"CIVIS"` como headsign (por algún edge case), debería mostrarlo como un badge express, no como destino.

### RouteShapeResponse: falta `is_circular`

La API manda `is_circular` en la shape response pero nuestro modelo no lo tiene. Útil para evitar dibujar línea de cierre entre última y primera parada en líneas no circulares.
