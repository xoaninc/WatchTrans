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

### CompactDepartureResponse: no existe modelo

La API tiene `?compact=true` para departures con esquema reducido. No hay modelo en la app. Necesario para Widgets iOS y Siri Shortcuts.

### UI pendiente para campos ya decodificados

- **Platform confidence** — deferred al ROADMAP

### route-planner: parámetros nuevos no usados

El endpoint acepta `arrive_by` (hora de llegada), `travel_date` (fecha distinta de hoy), y `compact`. La app no los usa.

### /stops/by-coordinates: param `route_types` no usado

Filtrar paradas por tipo de transporte. Útil para búsqueda filtrada.

### ~~NetworkResponse dead fields~~ ✅ RESUELTO

Eliminados `region`, `logoUrl`, `wikipediaUrl`, `description`, `nucleoIdRenfe`.

### ~~StopFullDetailResponse faltan campos~~ ✅ RESUELTO

Añadidos `acercaService`, `serviceStatus`, `suspendedSince`.

### ~~Pathway modes 3-6~~ ✅ RESUELTO

Iconos para moving_sidewalk, escalator, elevator, fare_gate.

### ~~is_skipped no se filtra~~ ✅ RESUELTO

Departures con `is_skipped == true` se filtran en GTFSRealtimeMapper (ambos targets).

### ~~is_alternative_service sin icono~~ ✅ RESUELTO

Icono bus naranja en ArrivalRowView cuando `isAlternativeService == true`.

### ~~Express CIVIS badge~~ ✅ IMPLEMENTADO

Badge con `expressName` ("CIVIS") y `expressColor` en ArrivalRowView.

### ~~PMR warning per-departure~~ ✅ IMPLEMENTADO

Icono ⚠️♿ naranja en ArrivalRowView cuando `pmrWarning == true`.

### ~~parkingBicis como parking genérico~~ ✅ RESUELTO

Badge cambiado de "Parking" con icono P a "Parking Bici" con icono 🚲.

### ~~Fases de alertas~~ ✅ IMPLEMENTADO

`AlertBannerView` muestra fases temporales con fechas y colores por efecto cuando hay >1 active_period.
