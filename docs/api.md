# WatchTrans App — API Usage Map

**Base URL:** `https://api.watch-trans.app`
**Última actualización:** 2026-04-13
**Autenticación:** `Authorization: Bearer {key}` requerido en todas las requests (desde 2026-04-13). Key en `APISecrets.swift` (gitignored).

Referencia de qué endpoints consume la app y cuáles no.
Fuente de verdad del servidor: `/Users/juanmaciasgomez/Projects/WatchTrans_Server/docs/API_ENDPOINTS.md`

---

## GTFS Static (`/api/gtfs/`)

| Endpoint | Estado | Dónde se usa |
|----------|--------|-------------|
| `GET /stops/by-coordinates` | ✅ | `DataService.fetchTransportData` — carga principal al arrancar |
| `GET /stops/{stop_id}` | ✅ | `DataService.fetchStopDetails` — detalle individual |
| `GET /stops/{stop_id}/departures` | ✅ | `DataService.fetchArrivals` — endpoint principal de salidas |
| `GET /stops/{stop_id}/full` | ⚠️ Solo iOS | `StopDetailView.loadData` — correspondencias, andenes, accesos, accesibilidad |
| `GET /stops/{stop_id}/platforms` | ✅ | `DataService.fetchPlatforms` — coordenadas de andenes |
| `GET /stops/{stop_id}/accesses` | ⚠️ Solo iOS | `DataService.fetchAccesses` — bocas de metro (fallback si no hay station-interior) |
| `GET /stops/{stop_id}/station-interior` | ⚠️ Solo iOS | `StopDetailView.loadData` — pathways, vestíbulos, niveles |
| `GET /stops/{stop_id}/correspondences` | ✅ | `DataService.fetchCorrespondences` — estaciones a pie |
| `GET /stops/{stop_id}/children` | ⚠️ Solo iOS | `DataService.fetchChildren` — andenes hijos |
| `GET /stops?search=` | ✅ | `DataService.fetchStops` — búsqueda por nombre |
| `GET /routes/{route_id}` | ✅ | `DataService.fetchRouteDetail` — detalle de ruta. ⚠️ Campo `branches` ignorado: el modelo Swift no lo declara, Swift descarta silenciosamente el campo JSON. La app muestra la ruta completa sin conciencia de ramas. |
| `GET /routes/{route_id}/stops` | ✅ | `DataService.fetchStopsForRoute` — paradas de una línea |
| `GET /routes/{route_id}/shape` | ✅ | `DataService.fetchRouteShape` — polyline para mapa |
| `GET /routes/{route_id}/frequencies` | ✅ | `GTFSRealtimeService.fetchFrequencies` — frecuencias metro |
| `GET /routes/{route_id}/operating-hours` | ✅ | `DataService.fetchOperatingHours` — horarios cercanías |
| `GET /networks` | ✅ | `DataService.fetchLinesIfNeeded` — transport types |
| `GET /networks/{code}/lines` | ✅ | `DataService.fetchLinesIfNeeded` — líneas por red |
| `GET /province-by-coordinates` | ✅ | `DataService.setLocationContextFromStops` — detección provincia |
| `GET /province/{name}/routes` | ✅ | `DataService.fetchLinesIfNeeded` — rutas por provincia |
| `GET /coordinates/routes` | ✅ | `GTFSRealtimeService.fetchNearbyRoutes` — rutas cercanas |
| `GET /route-planner` | ✅ | `DataService.fetchRoutePlan` — RAPTOR journey |
| `GET /route-planner/range` | ⚠️ Solo iOS | `DataService.fetchRoutePlanRange` — rRAPTOR por franja |
| `GET /trips/{trip_id}` | ✅ | `DataService.fetchTrip` — detalle de viaje |
| `GET /stops/{stop_id}/facilities` | ❌ | Facilidades de estación (parking, patinetes, atención al cliente). No implementado. |
| `GET /stops/{id}/departures?compact=true` | ❌ | Modelo `CompactDepartureResponse` no existe. Pendiente para Widgets. |
| `GET /stops/{stop_id}/air-quality` | ❌ | Calidad del aire ambiente (ICA 1-5, contaminantes, estación Gencat XVPCA). Solo paradas Catalunya. No implementado. |
| `GET /routes/{route_id}/fares` | ⚠️ Solo iOS | `LineDetailView` — tarifas por zona |
| `GET /routes/{route_id}/patterns` | ❌ | Trip patterns agrupados en ramas jerárquicas. Relacionado con el campo `branches` ignorado en `/routes/{id}`. |
| `GET /operators/{operator_id}/fares` | ❌ | CMS fares. No prioritario. |
| `GET /agencies` | ❌ | Uso interno. |
| `GET /agencies/{agency_id}/policies` | ❌ | Políticas del operador (mascotas, comida, fotografía). No implementado. |
| `GET /coordinates/lines` | ❌ | No prioritario. |
| `GET /province/{name}/lines` | ❌ | No prioritario. |
| `GET /journey/isochrone` | ❌ | No prioritario. |
| `GET /translations` | ❌ | 891 traducciones (EN/FR/ES/EU). Euskotren y Metro Madrid. |
| `GET /transfers` | ❌ | Tiempos mínimos de transbordo entre paradas. |
| `GET /feed-info` | ❌ | Frescura de datos GTFS por operador. |
| `GET /interchanges` | ❌ | 76 intercambiadores (mayoría Madrid CRTM). |
| `GET /interchanges/{code}` | ❌ | Detalle con todas las paradas del intercambiador. |

## GTFS-RT (`/api/gtfs-rt/`)

| Endpoint | Estado | Dónde se usa |
|----------|--------|-------------|
| `GET /alerts` | ✅ | `DataService.fetchAlertsForStop/Route/Line` — alertas con filtros |
| `GET /alerts?route_id=` | ✅ | `GTFSRealtimeService.fetchAlertsForRoute` |
| `GET /alerts?stop_id=` | ✅ | `GTFSRealtimeService.fetchAlertsForStop` |
| `GET /vehicles/{vehicle_id}` | ✅ | `GTFSRealtimeService.fetchVehicleById` |
| `GET /platforms/predictions` | ✅ | `DataService.applyPlatformPredictions` — andén estimado |
| `GET /station-occupancy` | ⚠️ Solo iOS | `StopDetailView.loadData` — ocupación TMB |
| `GET /equipment-status/{stop_id}` | ⚠️ Solo iOS | `StopDetailView.loadData` — ascensores Metro Sevilla |
| `GET /stats` | ⚠️ Dead code | Fetch existe, nunca se llama |
| `GET /trip-updates` | ✅ | `TrainDetailView` — delay preciso (min+seg) |
| `GET /stops/{stop_id}/realtime` | ⚠️ Dead code | Fetch existe, nunca se llama. Legacy/debug. |
| `GET /vehicles` | ✅ | `StopDetailView` — air quality Metro Sevilla |
| `GET /occupancy` | ⚠️ Solo iOS | `StopDetailView` — ocupación vehículos FGC |
| `GET /air-quality/` | ❌ | Endpoint dedicado calidad aire Metro Sevilla. App usa `/vehicles?enrich=true`. ROADMAP 3.25. |
| `GET /vehicles/{id}/occupancy/per-car` | ❌ | Sin datos consistentes. |
| `GET /stop-time-updates` | ❌ | Duplica departures. |
| `GET /equipment-status/?operator_id=` | ❌ | Bulk. Per-stop ya se usa. |
| `GET /station-status/` | ❌ | Estado abierta/cerrada de estaciones (Metro Madrid). Bulk no implementado. |
| `GET /station-status/{stop_id}` | ❌ | Estado de una estación específica (Metro Madrid). No implementado. |
| `GET /access-status/{stop_id}` | ❌ | Estado de accesos de una estación (Metro Madrid). No implementado. |

## Admin

| Endpoint | Estado |
|----------|--------|
| `POST /fetch/{operator_id}` | ⚠️ Dead code |
| `POST /cleanup` | ⚠️ Dead code |
| `GET /admin/dlq` | ❌ |
| `POST /admin/dlq/{id}/retry` | ❌ |
| `POST /admin/dlq/{id}/dismiss` | ❌ |
| `GET /admin/dlq/stats` | ❌ |
| `GET /cache/stats` | ❌ |
| `POST /cache/invalidate` | ❌ |

## Resumen

| Categoría | ✅ iOS+Watch | ⚠️ Solo iOS | ⚠️ Dead code | ❌ No usados |
|-----------|-------------|-------------|--------------|-------------|
| GTFS Static | 17 | 6 | 0 | 15 |
| GTFS-RT | 8 | 4 | 2 | 7 |
| Admin | 0 | 0 | 2 | 6 |
| **Total** | **25** | **10** | **4** | **28** |

## Auditoría en vivo (2026-04-20, ~00:30h)

Resultados de probar todos los endpoints marcados ✅ contra `https://api.watch-trans.app` con el key de producción:

**OK (22/22 probados):** `/networks`, `/networks/{code}/lines`, `/stops?search`, `/stops/by-coordinates`, `/stops/{id}`, `/stops/{id}/departures` (incluyendo `?compact=true`), `/full`, `/platforms`, `/correspondences`, `/children`, `/accesses`, `/station-interior`, `/province-by-coordinates`, `/province/{name}/routes`, `/coordinates/routes`, `/routes/{id}` (+ `/stops`, `/shape`, `/operating-hours`), `/trips/{id}`, `/platforms/predictions?stop_id=`, `/vehicles`, `/vehicles/{id}?operator_id=`, `/trip-updates?stop_id=`, `/alerts` (global/stop/route), `/occupancy?operator_id=`.

**Vacíos legítimos (cierre nocturno):** `/vehicles?operator_id=metro_sevilla`, `/equipment-status/{sevilla_stop}`, `/alerts?route_id=MMAD_L1`, `/routes/MMAD_L1/frequencies`. `/stops/{id}/facilities` vacío para stop Cercanías (solo Metro Sevilla tiene datos).

**Problemas detectados — ver `docs/pending.md#bugs-activos`:**
- 🚨 `/station-occupancy` devuelve 254 entradas TMB con timestamp de hace 30 días (feed congelado).
- 🚨 `/route-planner` roto para **todo** Madrid (Metro + Cercanías). FGC Barcelona sí funciona.
- ⚠️ `/vehicles` tiene `agency_id: null` (pero `operator_id` sí — la app usa el último).
- ⚠️ `/province/{name}/routes` tardó 7.3s (el resto <1s).

## Notas de cambios del backend (2026-03-18)

- `alternative_service_warning` ahora es per-ruta, no per-stop. Solo true cuando hay transporte alternativo REAL.
- `express_color` para CIVIS ahora es `"E95EBE"` (rosa).
- `wheelchair_boarding` arreglado en `/stops/{stop_id}` (antes era siempre null).
- Alertas de accesibilidad ahora solo se asocian a rutas que pasan por la parada afectada.
- `estimated_restoration_time` tipo string (texto humano), no datetime.
- ~~`parking_bicis`~~ Reemplazado por `bicycle_parking` (int tri-state 0/1/2) + `car_parking` (int tri-state 0/1/2) desde 2026-04-13. `acerca_service.parking` sigue siendo parking de coches Adif (solo 56 estaciones).
- Operadores RT: `renfe`, `tmb`, `fgc`, `euskotren`, `metro_bilbao`, `metro_madrid`, `mlo`, `metro_sevilla`, `tram_sevilla`, `tranvia_zaragoza`.
- Interior source `combined` nuevo para estaciones con datos mixtos.

## Campos consumidos (2026-03-21)

**En departures (implementados):**
- `train_code` — código operativo del tren (Renfe, TMB, Metro Bilbao, Metro Sevilla, Tram Sevilla)
- `trip_short_name` — número de tren en TrainDetailView
- `wheelchair_accessible_static` — accesibilidad estática, complementa RT
- `bikes_allowed` — badge bici en departures

**En routes (implementados):**
- `alternative_for_short_name` — "Sustituye C1" en LinesListView

**En routes (no consumidos):**
- `branches` — array de ramas precomputadas (calendar-aware desde 2026-04-04). El modelo Swift `RouteResponse` declara el campo `branches: [BranchInfo]?`. Se decodifica pero la UI aún no lo consume — la app muestra la ruta completa sin separar ramas A/B. Ver `/routes/{route_id}/patterns` para el endpoint complementario.

## Campos disponibles no consumidos (2026-03-21)

**En departures:**
- ~~`vehicle_composition`~~ ✅ IMPLEMENTADO — `"single"`/`"double"` para Metro Sevilla.

**En alerts:**
- `alternative_transport[]` detalles — ruta bus, frecuencia. App solo usa boolean. ROADMAP 3.26.
- `content` + `image_url` — contenido rico en alertas Metro Sevilla news. ROADMAP 3.27.

**En stops:**
- `zone_id` — zona tarifaria (Euskotren, FGC, TMB, Metro Sevilla, Metro Valencia, Tram Alicante). Campo añadido al modelo pero comentado — pendiente UI.

**En routes:**
- `route_url` — URL de la página del operador

**Endpoints no integrados:**
- ~~`GET /api/gtfs-rt/air-quality/`~~ ✅ IMPLEMENTADO — calidad aire Metro Sevilla con match por train_code.

## Notas de cambios del backend (2026-03-21)

- `train_code` nuevo campo en departures, vehicles, trip-updates. Código operativo limpio extraído de `vehicle_id`.
- `alternative_service_warning` ahora solo mira `route_id` del departure, no `stop_id` compartido.
- `alternative_service_warning` solo con alternative_transport real (NO_SERVICE/DETOUR siempre; MODIFIED/REDUCED solo con bus/reroute).
- Equipment status: `direction: "disabled"` con `is_operational: true` = equipo no disponible.
- Metro Sevilla + Tram Sevilla + Tranvía Zaragoza añadidos a `ALLOWED_RT_OPERATORS`.
- Tram Sevilla alertas implementadas via Tussam avisos API. FlareSolverr reemplazado por Azure proxy (100% success, <5s).
- Delay buffer 90 min: backend no pierde trenes retrasados del tablero. Transparente para la app.
- Hybrid board enrichment: `bikes_allowed`, `wheelchair_accessible_static`, `trip_short_name` ahora poblados para operadores híbridos.

## Notas de cambios del backend (2026-03-21, segunda tanda)

- **Tram Sevilla departures**: `train_code` ahora devuelve número de vehículo (ej. "1309"), antes null. `wheelchair_accessible_static: 1` ahora poblado. `train_position` disponible con GPS.
- **Tram Sevilla vehicles**: `GET /vehicles?operator_id=tram_sevilla` ahora devuelve posiciones GPS. Campos nuevos: `destination`, `position_meters`, `fetch_timestamp`.
- **Agencies**: campo nuevo `text_color`.
- **Feed-info**: campos nuevos `contact_email`, `contact_url`, `default_language`.

## Notas de cambios del backend (2026-03-21, tercera tanda)

- **train_position.progress_percent**: ahora calculado via PostGIS (proyección GPS sobre shape real), 0-100%. Antes null o hardcoded. Funciona para Tram Sevilla, Metro Sevilla, Tranvía Zaragoza (cualquier operador con shapes + GPS).
- **train_position.current_stop_name/id**: ahora poblados con la parada más cercana al GPS del vehículo. Antes null para operadores híbridos.
- **train_code en train_position**: disponible dentro del objeto train_position (además de en el departure raíz).
- App ya decodifica todos estos campos — no requiere cambios de código.

## Notas de cambios del backend (2026-04-13)

- **`frequency_based` eliminado de departures**. Reemplazado por `route_type` (int, GTFS standard: 0=tram, 1=metro, 2=rail, 3=bus, 7=funicular). La app ahora usa `route_type == 2` donde antes usaba `frequency_based == false`. Lógica de display:
  - `route_type == 2` (rail) + ≥30 min → hora absoluta ("18:54")
  - `route_type != 2` + >30 min → "+ 30 min"
  - <30 min → "X min" para todos
- **`has_realtime`** nuevo campo bool en departures. No consumido por la app (la lógica de display usa `route_type`).
- `headway_secs` sigue presente (null para operadores con horarios exactos).

## Notas de cambios (2026-04-13)

- **API autenticada**: Todos los endpoints ahora requieren `Authorization: Bearer {key}`. Key almacenada en `APISecrets.swift` (gitignored), expuesta como `APIConfiguration.authHeader`.
- **`parking_bicis` → `bicycle_parking` + `car_parking`**: Campos tri-state (0=sin info, 1=disponible, 2=confirmado). Reemplazan el booleano `hasParking`. UI muestra iconos separados de bici (verde) y parking coches (azul) en StopHeaderView.
- **`description` en stops**: Nuevo campo `stopDescription` con dirección/notas de la estación. Se muestra como botón info (ℹ️) al lado del nombre que abre un popover.
- **`findLine` mejorado**: Busca por `routeId` en `routeIds` directamente, sin hardcoded name matching. Arregla líneas RT mostrando `MMAD_L12` en vez de `L12`.
- **`branches` decodificado**: `RouteResponse.branches: [BranchInfo]?` ahora se decodifica correctamente. Solo L6 Madrid tiene 2 ramas activas (sentidos circular). UI pendiente.
