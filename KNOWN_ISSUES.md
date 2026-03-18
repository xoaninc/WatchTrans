# Known Issues

## ~~StopAlertBadge shows on all Renfe stations~~ ✅ RESUELTO

## ~~API field renames not propagated~~ ✅ RESUELTO

## ~~Equipment status de Metro Sevilla~~ ✅ RESUELTO

## ~~Líneas no cargadas hasta entrar en sección Líneas~~ ✅ RESUELTO

## ~~LineResponse CodingKeys desactualizados~~ ✅ RESUELTO

Corregido: `route_color` y `route_text_color` en `LineResponse` y `LineRouteInfo`.

## ~~DepartureResponse campos nuevos~~ ✅ MODELOS AÑADIDOS

Campos decodificados pero sin UI: `isExpress`, `expressName`, `expressColor`, `pmrWarning`, `alternativeServiceWarning`, `wheelchairAccessibleNow`, `platformConfidence`, `delayEstimated`, `stationOccupancyPct`, `stationOccupancyStatus`. También `bearing`/`speed` en TrainPosition.

**Pendiente Plan B:** UI para express badge CIVIS, aviso PMR, aviso servicio alternativo.

## ~~AcercaService falta source~~ ✅ RESUELTO

## ~~Alertas severity_level~~ ✅ RESUELTO

API manda `severity_level`, no `severity`. CodingKey corregido.

## ~~Alertas active_periods fases~~ ✅ MODELOS AÑADIDOS

`AlertActivePeriod` struct con `effect` y `phaseDescription`. Decodifica pero sin UI todavía.

**Pendiente Plan B:** Mostrar fases temporales en alertas.

## ~~TrainPosition bearing/speed~~ ✅ RESUELTO

## ~~RouteOperatingHours falta source~~ ✅ RESUELTO

## ~~PlatformPrediction observationCount~~ ✅ RESUELTO

`observationCount` y `lastObserved` añadidos. `sampleSize` mantenido por backward compat.

## ~~RouteShapeResponse falta isCircular~~ ✅ RESUELTO

## ~~Euskotren IDs trailing colon~~ ✅ VERIFICADO — NO ES ISSUE

`URLComponents` maneja los colons correctamente. Probado con `EUSKOTREN_ES%3AEuskotren%3AStopPlace%3A1468%3A` — devuelve departures sin problema.

## ~~CIVIS como headsign~~ ✅ VERIFICADO — NO ES ISSUE

El servidor ya reemplaza "CIVIS" por la última parada. `is_express=true` y `express_name="CIVIS"` vienen como campos separados. Verificado en Madrid Atocha (C10 CIVIS).

---

## ACTIVOS

### parkingBicis se usa como parking genérico

`parkingBicis` se mapea a `hasParking` → badge "Parking" genérico. No distingue parking de bicis de parking de coches. No hay badge específico de bicis.

### CompactDepartureResponse: no existe modelo

La API tiene `?compact=true` para departures con esquema reducido. No hay modelo en la app. Necesario para Widgets iOS y Siri Shortcuts.

### UI pendiente para campos ya decodificados

- **Aviso servicio alternativo** — `alternativeServiceWarning` — investigando, problema pendiente
- **Platform confidence** — deferred al ROADMAP

### StopFullDetailResponse: faltan campos

`/stops/{id}/full` devuelve `acerca_service`, `service_status`, `suspended_since` pero nuestro modelo `StopFullDetailResponse` no los tiene.

### route-planner: parámetros nuevos no usados

El endpoint acepta `arrive_by` (hora de llegada, mutuamente exclusivo con `departure_time`), `travel_date` (fecha distinta de hoy), y `compact`. La app no los usa.

### /stops/by-coordinates: param `route_types` no usado

Se puede filtrar paradas por tipo de transporte (`route_types=1` para solo metro, `2` para solo tren, etc.). Útil para búsqueda filtrada.

### StationInteriorSection: faltan pathway modes 3-6

Solo hay iconos para walkway (1) y stairs (2). Faltan: moving_sidewalk (3), escalator (4), elevator (5), fare_gate (6). Cuando la API devuelva estos modos, la vista mostrará el icono genérico de walkway.

### is_skipped departures no se filtran

Cuando `is_skipped == true`, el tren salta esa parada y no para. La app decodifica el campo pero no filtra estos departures — los muestra como salidas válidas. El usuario vería un tren que no va a parar en su estación.

### is_alternative_service: sin icono diferente

Cuando una ruta tiene `is_alternative_service == true` (servicio de sustitución por bus), la app no lo indica. Debería mostrar icono de bus en vez de tren.

### ~~Express CIVIS badge~~ ✅ IMPLEMENTADO

Badge con `expressName` ("CIVIS") y `expressColor` en ArrivalRowView.

### ~~PMR warning per-departure~~ ✅ IMPLEMENTADO

Icono ⚠️♿ naranja en ArrivalRowView cuando `pmrWarning == true`.

### ~~parkingBicis como parking genérico~~ ✅ RESUELTO

Badge cambiado de "Parking" con icono P a "Parking Bici" con icono 🚲.

### ~~Fases de alertas~~ ✅ IMPLEMENTADO

`AlertBannerView` muestra fases temporales con fechas y colores por efecto cuando hay >1 active_period.
