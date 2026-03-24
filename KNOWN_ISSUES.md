# Known Issues

## ~~StopAlertBadge shows on all Renfe stations~~ ✅ RESUELTO

## ~~API field renames not propagated~~ ✅ RESUELTO

## ~~Equipment status de Metro Sevilla~~ ✅ RESUELTO

## ~~Líneas no cargadas hasta entrar en sección Líneas~~ ✅ RESUELTO

## ~~LineResponse CodingKeys desactualizados~~ ✅ RESUELTO

Corregido: `route_color` y `route_text_color` en `LineResponse` y `LineRouteInfo`.

## ~~DepartureResponse campos nuevos~~ ✅ IMPLEMENTADO

Todos los campos con UI: express CIVIS badge, PMR warning, alternative service, train_code. `platformConfidence` y `delayEstimated` decodificados sin UI (deferred).

## ~~AcercaService falta source~~ ✅ RESUELTO

## ~~Alertas severity_level~~ ✅ RESUELTO

API manda `severity_level`, no `severity`. CodingKey corregido.

## ~~Alertas active_periods fases~~ ✅ IMPLEMENTADO

`AlertActivePeriod` con fases temporales en `AlertBannerView`.

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

### ~~Hardcoded province→operator mappings~~ ✅ RESUELTO

Eliminados switch cases de metroSectionTitle, tramSectionTitle, isRodalies (LinesListView), relevantCredits (SettingsView), isCercaniasLine (Arrival). Ahora usan network.name y network.transportType de la API. LogoImageView, NativeAnimatedMapView y PDF paths se mantienen (asset selection, no datos de operador). city eliminado de NetworkResponse.

### CompactDepartureResponse: no existe modelo

La API tiene `?compact=true` para departures con esquema reducido. No hay modelo en la app. Necesario para Widgets iOS y Siri Shortcuts.

### UI pendiente para campos ya decodificados

- **Platform confidence** — deferred al ROADMAP

### route-planner: parámetros parcialmente usados

`departure_time` con DatePicker ya funciona (rango horario). Pendientes: `arrive_by` (llegar A las X), `travel_date` (otro día), `compact` (respuesta ligera).

### ~~Campos nuevos en departures no consumidos~~ ✅ IMPLEMENTADO

`trip_short_name`, `wheelchair_accessible_static`, `bikes_allowed`, `train_code` — todos decodificados y con UI.

### Campos nuevos en stops no consumidos

| Campo | Para qué sirve |
|---|---|
| `zone_id` | Zona tarifaria (ej. "A", "B1"). Euskotren, FGC, TMB, Metro Sevilla, Metro Valencia. |

### ~~Campo nuevo en routes no consumido~~ ✅ IMPLEMENTADO

`alternative_for_short_name` — "Sustituye C1" en LinesListView.

### ~~vehicle_composition campo dedicado no usado~~ ✅ IMPLEMENTADO

`vehicle_composition` decodificado. Mapper usa campo API primero, fallback a hack comma en `tripId`.

### ~~alternative_transport detalles no mostrados~~ ✅ UI IMPLEMENTADA (pendiente backend)

UI existe en StopDetailView y LineDetailView. Pero `alternative_transport` es siempre `null` en la API — Groq extrae la info pero no se expone en el campo. Cuando el backend lo popule, la app lo mostrará automáticamente.

### Alertas Metro Sevilla: content + image_url no mostrados

Alertas de noticias de Metro Sevilla tienen `content` (HTML) e `image_url`. La app solo muestra `headerText`/`descriptionText`.

### ~~Endpoint /air-quality/ no integrado~~ ✅ IMPLEMENTADO

Migrado a `GET /api/gtfs-rt/air-quality/`. Match por `train_code` ↔ `vehicle_id`.

### /stops/by-coordinates: param `route_types` no usado

Filtrar paradas por tipo de transporte (ej. `?route_types=1` solo metro, `?route_types=2` solo tren). Útil para añadir un selector de tipo de transporte en el mapa o en la sección de búsqueda. Pendiente decidir ubicación en la UI.

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

### AIGA symbols: marco legal pendiente

Los iconos AIGA (ElevatorSymbol, EscalatorSymbol, EscalatorUpSymbol, EscalatorDownSymbol, StairsSymbol) provienen del set AIGA Symbol Signs. StairClimbingSymbol proviene de otra fuente sin verificar. Set completo de 82 SVGs en `CustomSymbols/symbol_signs_aiga_svg/` (descargados de Wikimedia). Fuente original: https://www.aiga.org/resources/symbol-signs. ISO 7001 (191 SVGs) en `CustomSymbols/iso_7001_wikimedia_svg/`.

**Pendiente**: Verificar que "dominio público" (US Government work, 1974) aplica a distribución comercial en App Store. Verificar licencia de StairClimbingSymbol. Ver `CustomSymbols/SYMBOLS.md` para referencia completa.

### Colores de TransportType por revisar

Colores actuales (decididos por el usuario): metro=.orange, tren=.blue, tram=.green, bus=.red, funicular=.brown.

### Mapa de accesos: door.left.hand.open pendiente sustituir

`StopDetailView.swift:97` — Los pins del mapa de accesos usan `door.left.hand.open` para accesos no accesibles y `figure.roll` para accesibles. Todos los pins deberían usar `StairClimbingSymbol` (es una entrada/acceso). La accesibilidad (wheelchair) se indica aparte, no con el icono del pin.

### Pathway modes sin datos en la API

`StationInteriorSection PathwayRow` tiene iconos para `moving_sidewalk`, `escalator` (pathway), `elevator` (pathway), `fare_gate`, pero **ninguna estación de la API devuelve estos modes**. Solo existen `walkway` y `stairs`. Código preventivo pendiente de limpiar.
