# Known Issues

## ACTIVOS

### Backend: Metro Madrid Route Planner no funciona

RAPTOR devuelve "No journeys found" para estaciones de Metro Madrid. Hipótesis: el backend no ha cargado stop_times o transfers para Metro Madrid. Cercanías sí funciona.

### Backend: Equipment status solo Metro Sevilla

`equipment-status` solo tiene datos RT para Metro Sevilla (fuente TCE). Cuando otros operadores tengan feed RT de equipos, el endpoint los expondrá automáticamente. No requiere cambios en la app.

### CompactDepartureResponse: no existe modelo

La API tiene `?compact=true` para departures con esquema reducido. No hay modelo en la app. Necesario para Widgets iOS y Siri Shortcuts.

### Platform confidence sin UI

Campo decodificado, sin UI. Deferred.

### route-planner: parámetros parcialmente usados

`departure_time` con DatePicker ya funciona (rango horario). Pendientes: `arrive_by` (llegar A las X), `travel_date` (otro día), `compact` (respuesta ligera).

### zone_id en stops no consumido

Zona tarifaria (ej. "A", "B1"). Euskotren, FGC, TMB, Metro Sevilla, Metro Valencia. Pendiente UI.

### alternative_transport detalles pendiente backend

UI existe en StopDetailView y LineDetailView. Pero `alternative_transport` es siempre `null` en la API. Cuando el backend lo popule, la app lo mostrará automáticamente.

### Alertas Metro Sevilla: content + image_url no mostrados

Alertas de noticias de Metro Sevilla tienen `content` (HTML) e `image_url`. La app solo muestra `headerText`/`descriptionText`.

### /stops/by-coordinates: param `route_types` no usado

Filtrar paradas por tipo de transporte. Pendiente decidir ubicación en la UI.

### corBus — correspondencia bus sin badges

El campo `cor_bus` se envía en stops pero la app no muestra badges de correspondencia bus en `ConnectionsSectionView`.

### transport_type en /networks pendiente backend

La app usa `dataService.networkDisplayName(for:)` y `networkTransportType(_:)` que dependen de `transport_type` en `/networks`. El backend aún no lo manda — sin este campo las secciones de líneas no agrupan correctamente. Ver `docs/api-requests-pending.md`.

### PDFs de planos: naming por network code pendiente backend

La app construye URLs de planos como `{baseURL}/{type}/{network_code}.pdf`. Los PDFs en el servidor usan nombres legacy (`metro/sevilla_metro.pdf`). Hay que renombrarlos o añadir `plan_url` a `/networks`.

### arrive_by implementado pero no verificado

Segmented control `[Salir a las | Llegar a las]` añadido en JourneyPlannerView. Envía `arrive_by` a la API. Pendiente verificar que el backend lo soporta correctamente.

### AIGA symbols: marco legal pendiente

Los iconos AIGA provienen del set AIGA Symbol Signs (dominio público, US Government 1974). StairClimbingSymbol de otra fuente sin verificar. Ver `CustomSymbols/SYMBOLS.md`.

---

<details>
<summary>Archivo — Issues resueltos</summary>

- ~~StopAlertBadge shows on all Renfe stations~~ ✅
- ~~API field renames not propagated~~ ✅
- ~~Equipment status de Metro Sevilla~~ ✅
- ~~Líneas no cargadas hasta entrar en sección Líneas~~ ✅
- ~~LineResponse CodingKeys desactualizados~~ ✅
- ~~DepartureResponse campos nuevos~~ ✅ — express CIVIS, PMR warning, alternative service, train_code
- ~~AcercaService falta source~~ ✅
- ~~Alertas severity_level~~ ✅
- ~~Alertas active_periods fases~~ ✅
- ~~TrainPosition bearing/speed~~ ✅
- ~~RouteOperatingHours falta source~~ ✅
- ~~PlatformPrediction observationCount~~ ✅
- ~~RouteShapeResponse falta isCircular~~ ✅
- ~~Euskotren IDs trailing colon~~ ✅ — NO ES ISSUE
- ~~CIVIS como headsign~~ ✅ — NO ES ISSUE
- ~~Hardcoded province→operator mappings~~ ✅
- ~~Campos nuevos en departures~~ ✅ — trip_short_name, wheelchair_accessible_static, bikes_allowed, train_code
- ~~Campo nuevo en routes~~ ✅ — alternative_for_short_name
- ~~vehicle_composition campo dedicado~~ ✅
- ~~Endpoint /air-quality/~~ ✅
- ~~NetworkResponse dead fields~~ ✅
- ~~StopFullDetailResponse faltan campos~~ ✅
- ~~Pathway modes 3-6~~ ✅
- ~~is_skipped no se filtra~~ ✅
- ~~is_alternative_service sin icono~~ ✅
- ~~Express CIVIS badge~~ ✅
- ~~PMR warning per-departure~~ ✅
- ~~parkingBicis como parking genérico~~ ✅
- ~~Fases de alertas~~ ✅
- ~~Colores de TransportType~~ ✅
- ~~Mapa de accesos door.left.hand.open~~ ✅
- ~~Pathway modes sin datos~~ ✅

</details>
