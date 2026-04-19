# Pendientes

Unifica bugs activos, features pendientes, UI pendiente y requisitos de backend.
Sustituye a los antiguos `ROADMAP.md`, `KNOWN_ISSUES.md` y `docs/api-requests-pending.md`.

**Última actualización:** 2026-04-20 (tras auditoría de endpoints en vivo)

---

## Índice

- [Bugs activos](#bugs-activos)
- [Features pendientes](#features-pendientes)
- [Endpoints disponibles sin consumir](#endpoints-disponibles-sin-consumir)
- [Campos disponibles sin consumir](#campos-disponibles-sin-consumir)
- [Requisitos pendientes del backend](#requisitos-pendientes-del-backend)
- [UI pendiente](#ui-pendiente)
- [Pendiente replicar en Watch](#pendiente-replicar-en-watch)
- [Features futuras (v2+)](#features-futuras-v2)
- [Marco legal de símbolos](#marco-legal-de-símbolos)
- [Archivo — issues resueltos](#archivo--issues-resueltos)

---

## Bugs activos

### Bug MapKit: Polyline desaparece con rotación
Al rotar cámara (heading) en animación 3D, MapKit deja de renderizar polyline.
**Workaround actual:** Heading fijo a 0.
**Posible solución:** Usar `suggested_heading` de la API (ya viene en journey segments).

### Backend: Route Planner roto en Madrid (Metro + Cercanías)
RAPTOR devuelve `"No se encontró servicio en las próximas 24 horas"` (journeys: []) para **todos** los pares probados en Madrid, tanto Metro (MMAD_*) como Cercanías (RENFE_C_*). Probado 2026-04-20:
- `RENFE_C_18000` (Atocha) → `RENFE_C_17000` (Chamartín) → vacío
- `RENFE_C_18000` → `RENFE_C_10204` (Recoletos) → vacío
- `RENFE_C_18000` → `RENFE_C_18002` (Nuevos Ministerios) → vacío
- `MMAD_48_STATION` (Sol) → `MMAD_189_STATION` (Chamartín metro) → vacío

**FGC Barcelona sí funciona** (`FGC_PC` → `FGC_SC` devuelve journeys). Previamente se creía que solo Metro Madrid estaba roto y Cercanías funcionaba — auditoría del 2026-04-20 muestra que Cercanías Madrid también falla. Hipótesis: backend no ha cargado stop_times/transfers para las redes de Madrid.

### Backend: /station-occupancy con feed congelado (~1 mes)
`GET /api/gtfs-rt/station-occupancy` devuelve 254 entradas TMB, **todas con `updated_at: 2026-03-21T11:12:26Z`** (auditoría 2026-04-20). El ingest del feed lleva 30 días sin actualizarse. La app muestra ocupación stale sin señalarlo al usuario.
- Workaround app: añadir filtro por antigüedad (`updated_at` > ahora - N min) antes de mostrar.
- Fix real: arreglar ingest del feed TMB en backend.

### Backend: /vehicles sin `agency_id`
`GET /api/gtfs-rt/vehicles` devuelve `agency_id: null` en los 71 vehículos (FGC, TMB, Renfe, Tranvía Zaragoza, Metro Tenerife). `operator_id` sí está poblado. **No afecta a la app** — `fetchVehicleById` usa `operator_id`. Queda documentado por si algún caller futuro espera `agency_id`.

### Performance: /province/{name}/routes lento
`GET /api/gtfs/province/Madrid/routes` tardó 7.3s (auditoría 2026-04-20, 42 rutas). El resto de endpoints responden en <1s. Candidato a optimización/cache en backend.

### Backend: Equipment status ahora también Metro Madrid
`equipment-status` ahora cubre Metro Sevilla (fuente TCE) **y Metro Madrid (desde 2026-04-01, fetcher ctmulti)**. La app tiene código para ambos pero falta verificar UI con stops de Metro Madrid. Cuando otros operadores tengan feed RT de equipos, el endpoint los expondrá automáticamente.

### CompactDepartureResponse: no existe modelo
La API tiene `?compact=true` para departures con esquema reducido. No hay modelo en la app. Necesario para Widgets iOS y Siri Shortcuts.

### Platform confidence sin UI
Campo `platform_confidence` (0-1) decodificado, sin UI. Deferred.

### `status_estimated` disponible, sin consumir
Campo nuevo en `/stops/{id}/departures` (2026-04-19). Marca si `current_status` viene de GPS real (false) o inferido vía dead-reckoning con schedule+delay (true). Útil para reducir "fantasmas" en la UI (mostrar tren como IN_TRANSIT aunque el feed VP esté obsoleto). Ligado a KI #304 del servidor. App no lo consume aún.

### `current_stop_sequence` null para 7 operadores hybrid
Documentado oficialmente por el servidor: `current_stop_sequence` en `/gtfs-rt/vehicles` permanece `null` para **tmb, metro_madrid, mlo, tranvia_zaragoza, tram_sevilla, metro_sevilla, metro_tenerife**. Sub-issue KI #304 pendiente en backend. Sin este campo, la posición precisa del tren en el recorrido (antes/después de la siguiente parada) no es fiable para estos operadores.

### route-planner: parámetros parcialmente usados
`departure_time` con DatePicker ya funciona (rango horario). Pendientes: `arrive_by` (llegar A las X), `travel_date` (otro día), `compact` (respuesta ligera).

### zone_id en stops no consumido
Zona tarifaria (ej. "A", "B1"). Euskotren, FGC, TMB, Metro Sevilla, Metro Valencia, Tram Alicante. Campo añadido al modelo pero comentado — pendiente UI.

### alternative_transport detalles pendiente backend
UI existe en StopDetailView y LineDetailView. Pero `alternative_transport` es siempre `null` en la API. Cuando el backend lo popule, la app lo mostrará automáticamente.

### Alertas Metro Sevilla: content + image_url no mostrados
Alertas de noticias de Metro Sevilla tienen `content` (HTML) e `image_url`. La app solo muestra `headerText`/`descriptionText`.

### /stops/by-coordinates: param `route_types` no usado
Filtrar paradas por tipo de transporte. Pendiente decidir ubicación en la UI.

### transport_type en /networks pendiente backend
La app usa `dataService.networkDisplayName(for:)` y `networkTransportType(_:)` que dependen de `transport_type` en `/networks`. El backend aún no lo manda — sin este campo las secciones de líneas no agrupan correctamente. Ver sección [Requisitos pendientes del backend](#requisitos-pendientes-del-backend).

### PDFs de planos: naming por network code pendiente backend
La app construye URLs de planos como `{baseURL}/{type}/{network_code}.pdf`. Los PDFs en el servidor usan nombres legacy (`metro/sevilla_metro.pdf`). Hay que renombrarlos o añadir `plan_url` a `/networks`.

### arrive_by implementado pero no verificado
Segmented control `[Salir a las | Llegar a las]` añadido en JourneyPlannerView. Envía `arrive_by` a la API. Pendiente verificar que el backend lo soporta correctamente.

---

## Features pendientes

### Push Notifications para Alertas
Notificar cuando una línea favorita tiene incidencias. Requiere APNs + servidor.

### Watch Independiente
watchOS independiente con URLSession + sincronización de favoritos vía iCloud.

### Zona tarifaria en paradas
`zone_id` disponible en Euskotren, FGC, TMB, Metro Sevilla, Metro Valencia, Tram Alicante. Mostrar en StopDetailView.

### Mapa de vehículos en tiempo real
`destination` campo en `/vehicles`. Pins en mapa RT con label "→ destino". Requiere nueva vista.

### Detalles de transporte alternativo en alertas
`alternative_transport[]` tiene `type`, `route`, `frequency_minutes`. App solo usa boolean, no muestra detalles.

### Contenido rico en alertas Metro Sevilla
`content` (HTML) e `image_url` en alertas de noticias. Baja prioridad.

---

## Endpoints disponibles sin consumir

Endpoints que la API ya ofrece pero la app no usa:

| Endpoint | Qué ofrece | Prioridad |
|----------|-----------|-----------|
| `?compact=true` en departures | Formato ligero para widgets/Siri. Modelo `CompactDepartureResponse` necesario. | Alta |
| `GET /stops/{id}/facilities` | Facilities de estación (park & ride, atención al cliente, parking bici). Solo Metro Sevilla. | Media |
| `GET /interchanges` + `/{code}` | Hubs de intercambio con paradas agrupadas por código. | Media |
| `GET /transfers` | Tiempos de transbordo entre paradas (para mostrar en correspondencias). | Media |
| `GET /vehicles/{id}/occupancy/per-car` | Ocupación por vagón. Backend listo (FGC y Metro Madrid). | Media |
| `GET /routes/{route_id}/patterns` | Trip patterns agrupados jerárquicamente (trunk + short-turns/expresos), calendar-aware con cache 24h. Complementa `branches` de `/routes/{id}`. UI podría separar ramas durante obras. | Media |
| `GET /station-status/` + `/{stop_id}` | Estado abierto/cerrado de estaciones. Backend listo (Metro Madrid). | Baja |
| `GET /access-status/{stop_id}` | Estado de accesos abiertos/cerrados. Backend listo (Metro Madrid: ej. 6 accesos cerrados 2026-04-01). | Baja |
| `GET /air-quality/` (dedicado) | Metro Sevilla, CO2 + humedad + temperatura. App usa `/vehicles?enrich=true` como atajo. | Baja |
| `GET /equipment-status/?operator_id=` | Bulk por operador. Per-stop ya se usa. | Baja |
| `GET /agencies/{id}/policies` | Políticas del operador (mascotas, comida, patinetes, fotos). Solo Metro Sevilla. | Baja |
| `GET /coordinates/lines` | Líneas agrupadas cerca de coordenadas (alternativa a routes). | Baja |
| `GET /translations` | Nombres multilingüe GTFS (paradas, rutas). | Baja |
| `GET /feed-info` | Frescura del feed por operador (para mostrar "datos de hace X"). | Baja |
| `GET /journey/isochrone` | Paradas alcanzables en X minutos desde una parada. | Baja |
| `GET /stop-time-updates` | Predicciones RT arrival/departure. Duplica departures. | Baja |

---

## Campos disponibles sin consumir

Campos que la API ya envía pero la app ignora:

| Campo | Endpoint | Qué es |
|-------|----------|--------|
| `branches` | `/routes/{route_id}` | Array de ramas precomputadas (calendar-aware desde 2026-04-04). Modelo Swift `RouteResponse` lo decodifica pero la UI no lo consume. Solo L6 Madrid tiene 2 ramas activas. |
| `agency_name` | `/coordinates/routes`, `/networks/{code}/lines` | Nombre del operador — la app aún hace cruce con `/networks` por `code`. Pendiente integrar en `RouteResponse`. |
| `suggested_heading` | journey segments | Heading de cámara para animación 3D del journey. Podría resolver el bug de polyline con rotación. |
| `zone_id` | stops | Zona tarifaria. Campo en modelo pero comentado. |
| `route_url` | routes | URL de la página del operador. |
| `description` | stops | Descripción de la parada (Euskotren, Metro Sevilla, Metro Málaga). **NOTA:** ya se consume como `stopDescription` desde 2026-04-13. |
| `url` | stops | URL de la parada (Metro Tenerife, SFM Mallorca). |
| `parking_coches` | stops | Parking de coches (Metro Sevilla). **NOTA:** reemplazado por `car_parking` tri-state desde 2026-04-13. |

---

## Requisitos pendientes del backend

Campos/endpoints que la app necesita y la API no devuelve aún.

> **Nota (2026-04-13):** La API ahora requiere `Authorization: Bearer {key}`. Key en `APISecrets.swift` (gitignored). Campos `parking_bicis` reemplazados por `bicycle_parking`/`car_parking` (tri-state int). `description` nuevo campo en stops.

### GET /api/gtfs/networks — response actual

**Respuesta live (auditoría 2026-04-20):**
```json
{"code": "FGC", "name": "FGC", "has_realtime": true}
```

Solo tres campos. El Swift model tiene `transportType: String?` (valores tipo "cercanias"/"metro"/...) heredado de una iteración vieja del diseño — el backend confirma que **si algún día se añade `transport_type` al endpoint, será un int (GTFS route_type 0-7), no strings**. Cuando se añada, la app tendrá que cambiar el tipo del campo y su lógica de agrupación.

Campos que podrían añadirse sin bloquear nada (nice-to-have):
- `logo`: URL/filename del logo del operador. Sin él, la app cae a icono genérico del transport type.
- Nombres de `name` más legibles: actualmente algunos son ilegibles tipo "AJUNTAMENT DE BUNYOLA R4" o "Consorcio Regional de Transportes de Madrid". Corrección en GTFS fuente.

### GET /api/gtfs/networks — campo `city` a borrar

`city` siempre es null. La app ya lo borró del modelo. El servidor puede dejar de mandarlo.

### Planos (PDFs)

La app construye la URL del plano como `{baseURL}/{type}/{network_code}.pdf`. Para que funcione, los PDFs en el servidor deben seguir esta convención de naming:

| Tipo | Path esperado | Ejemplo |
|------|--------------|---------|
| metro | `metro/{code}.pdf` | `metro/metro_sevilla.pdf` |
| cercanias | `cercanias/{code}.pdf` | `cercanias/renfe_c4.pdf` |
| tranvia | `tranvia/{code}.pdf` | `tranvia/tussam.pdf` |

Actualmente los PDFs en el servidor usan nombres como `metro/sevilla_metro.pdf`, `cercanias/madrid_cercanias.pdf`. Hay que renombrarlos para que matcheen el network code, o añadir un campo `plan_url` a `/networks` para que la app no tenga que adivinar el path.

### GET /api/gtfs-rt/alerts — `alternative_transport`

Campo existe en el modelo Swift y la UI está implementada. Pero la API siempre devuelve `null`. Groq extrae la info del texto pero no la expone en el campo. Cuando se popule, la app mostrará automáticamente ruta del bus, frecuencia, estaciones de inicio/fin.

### GET /api/gtfs-rt/alerts — `content` + `image_url`

Alertas de noticias de Metro Sevilla. Servidor documenta ambos campos como disponibles (API_REALTIME.md:292-293). La app solo muestra `headerText`/`descriptionText`. Pendiente implementar UI con contenido rico e imágenes.

### GET /api/gtfs-rt/alerts — `ai_summary` + `ai_affected_segments`

Campos nuevos documentados por el servidor (no verificados en live): `ai_summary` (str) cuando description > 400 chars, `ai_affected_segments` (obj) con segmentos identificados por IA. App no los consume. Útiles para resúmenes de alertas largas.

### GET /api/gtfs/stops/{id} — campos de capabilities del operador

| Campo | Estado | Para qué lo necesita la app |
|-------|--------|---------------------------|
| `has_occupancy` | No existe | Saber si la parada tiene datos de ocupación en tiempo real. Sin este campo la app hace fetch para todas las paradas y el endpoint devuelve vacío. |
| `has_equipment_status` | No existe | Saber si la parada tiene estado de equipos (ascensores, escaleras). Sin este campo la app hace fetch para todas. |
| `has_air_quality` | No existe | Saber si la parada tiene datos de calidad del aire. Sin este campo la app hace fetch para todas. |


### Normalización de IDs de Renfe en alertas

`AlertFilterHelper` y `DataService` tienen lógica para normalizar IDs de Renfe que vienen en múltiples formatos del feed GTFS-RT de alertas (con/sin prefijo `RENFE_`, formatos legacy). Cuando la API normalice los IDs de alertas en el servidor, esta lógica del cliente se puede eliminar.

Archivos afectados:
- `WatchTrans iOS/Services/AlertFilterHelper.swift`
- `WatchTrans iOS/Services/DataService.swift` (normalizeStopId, fallback por ID legacy)
- `WatchTrans Watch App/Services/DataService.swift` (mismo)

### No requiere cambio de API (bugs de la app)

- **Pathway modes incompletos**: `/stops/{id}/station-interior` solo devuelve `walkway` y `stairs`. La app tiene código defensivo para `escalator`, `elevator`, `moving_sidewalk`, `fare_gate` pero ninguna estación los devuelve.

---

## UI pendiente

- Selector de líneas del mapa — cambiar `Menu` por `Sheet`/`Popover` con logos y badges de color
- Pathways en route planner — `signposted_as` como texto principal

---

## Pendiente replicar en Watch

- Ocupación estación TMB
- Búsqueda en rango horario
- Interior de estaciones
- Accesibilidad (badges, Acerca PMR)
- Train code
- Correspondencias navegables
- Journey stops navegables

---

## Features futuras (v2+)

| Feature | Notas |
|---------|-------|
| Ticketing / Payment | Requiere acuerdos con operadores (Masabi JustRide SDK) |
| Bike-share (BiciMAD, Bicing) | GBFS spec |
| CarPlay | Complejidad alta |
| Mapas Offline | MapLibre + vector tiles |
| Reportar Incidencias | Open311 |

---

## Marco legal de símbolos

**AIGA/DOT (Elevator, Escalator, Stairs):** ✅ Dominio público. US Government work (17 U.S.C. §105). Sin restricciones, sin atribución. SEGD confirma: "copyright-free symbols within the public domain". Wikimedia metadata: `Copyrighted: False`. **Seguro para App Store.**

**ISO 7001 Wikimedia (Metro, Tren, Tram, Bus, Funicular, Wheelchair, RedCross):** SVGs creados por usuario "Clemenspool" bajo CC0 (dominio público). Sin atribución requerida. ISO reclama copyright sobre los diseños originales (~$30/símbolo), pero los pictogramas son figuras geométricas simples que probablemente no pasan el umbral de originalidad para copyright (Feist v. Rural). **Riesgo muy bajo para app indie.**

**StairClimbingSymbol:** Fuente sin verificar (descargado por el usuario desde internet). **Pendiente verificar licencia antes de publicar.**

Fuentes: [SEGD](https://segd.org/resources/aiga-dot-symbols-for-transportation/), [Wikipedia DOT pictograms](https://en.wikipedia.org/wiki/DOT_pictograms), [ISO Copyright](https://www.iso.org/copyright.html), [Wikimedia CC0](https://commons.wikimedia.org/wiki/Category:ISO_7001_icons).

---

## Archivo — issues resueltos

- ~~`corBus` — correspondencia bus sin badges~~ ✅ Badges de bus implementados en iOS `StopDetailView` y Watch `LineDetailView`.
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
- ~~`route_type` en stops~~ ✅ — desde 2026-04-13, `/stops?search=`, `/stops/by-coordinates`, `/stops/{id}`
- ~~`route_type` en departures~~ ✅ — desde 2026-04-13, reemplaza `frequency_based`
- ~~`wheelchair_accessible` como Int~~ ✅ — `/stops/{id}/departures`, null/1/2/3
- ~~`agency_name` en `/coordinates/routes`~~ ✅ YA EXISTE — pendiente integrar en `RouteResponse` del cliente
- ~~Prefijo `RENFE_FEVE_*`~~ ✅ ELIMINADO (2026-03-28) — núcleos 45/46/47 fusionados en `RENFE_C_*`
- ~~`description` en stops~~ ✅ — Euskotren, Metro Sevilla, Metro Málaga. App muestra ℹ️ popover.
- ~~Endpoint `/air-quality/` dedicado~~ ✅ YA EXISTE — Metro Sevilla. App usa atajo vía `/vehicles?enrich=true`.
- ~~`branches` precomputado calendar-aware~~ ✅ YA EXISTE — desde 2026-04-04. UI sigue pendiente (L6 Madrid 2 ramas).
- ~~`vehicle_composition` single/double~~ ✅ — Metro Sevilla.
- ~~Equipment status Metro Madrid~~ ✅ — desde 2026-04-01, fetcher ctmulti. App tiene código; falta verificar UI con Metro Madrid.
- ~~`/vehicles/{id}/occupancy/per-car`~~ ✅ YA EXISTE — FGC + Metro Madrid. App no lo consume.
- ~~Tram Sevilla RT (vehicles + alerts)~~ ✅ — 2026-03-21. GPS + Tussam avisos via Azure proxy.
- ~~`platform_confidence` en departures~~ ✅ — score 0-1 para predicciones estadísticas de andén.
