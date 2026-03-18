# WatchTrans App — API Usage Map

**Base URL:** `https://api.watch-trans.app`
**Última actualización:** 2026-03-18

Referencia de qué endpoints consume la app y cuáles no.

---

## GTFS Static (`/api/gtfs/`)

| Endpoint | Estado | Dónde se usa |
|----------|--------|-------------|
| `GET /stops/by-coordinates` | ✅ Usado | `DataService.fetchTransportData` — carga principal al arrancar |
| `GET /stops/{stop_id}` | ✅ Usado | `DataService.fetchStopDetails` — detalle individual |
| `GET /stops/{stop_id}/departures` | ✅ Usado | `DataService.fetchArrivals` — endpoint principal de salidas |
| `GET /stops/{stop_id}/full` | ✅ Usado | `StopDetailView.loadData` — correspondencias, andenes, accesos |
| `GET /stops/{stop_id}/platforms` | ✅ Usado | `DataService.fetchPlatforms` — coordenadas de andenes |
| `GET /stops/{stop_id}/accesses` | ✅ Usado | `DataService.fetchAccesses` — bocas de metro |
| `GET /stops/{stop_id}/station-interior` | ✅ Usado | `StopDetailView.loadData` — pathways, vestíbulos, niveles |
| `GET /stops/{stop_id}/correspondences` | ✅ Usado | `DataService.fetchCorrespondences` — estaciones a pie |
| `GET /stops/{stop_id}/children` | ✅ Usado | `DataService.fetchChildren` — andenes hijos |
| `GET /stops?search=` | ✅ Usado | `DataService.fetchStops` — búsqueda por nombre |
| `GET /routes/{route_id}/stops` | ✅ Usado | `DataService.fetchStopsForRoute` — paradas de una línea |
| `GET /routes/{route_id}/shape` | ✅ Usado | `DataService.fetchRouteShape` — polyline para mapa |
| `GET /routes/{route_id}/frequencies` | ✅ Usado | `GTFSRealtimeService.fetchFrequencies` — frecuencias metro |
| `GET /routes/{route_id}/operating-hours` | ✅ Usado | `DataService.fetchOperatingHours` — horarios cercanías |
| `GET /routes/{route_id}` | ✅ Usado | `DataService.fetchRouteDetail` — detalle de ruta |
| `GET /networks` | ✅ Usado | `DataService.fetchLinesIfNeeded` — transport types |
| `GET /networks/{code}/lines` | ✅ Usado | `DataService.fetchLinesIfNeeded` — líneas por red |
| `GET /province-by-coordinates` | ✅ Usado | `DataService.setLocationContextFromStops` — detección provincia |
| `GET /province/{name}/routes` | ✅ Usado | `DataService.fetchLinesIfNeeded` — rutas por provincia |
| `GET /coordinates/routes` | ✅ Usado | `GTFSRealtimeService.fetchNearbyRoutes` — rutas cercanas |
| `GET /route-planner` | ✅ Usado | `DataService.fetchRoutePlan` — RAPTOR journey |
| `GET /route-planner/range` | ✅ Usado | `DataService.fetchRoutePlanRange` — rRAPTOR por franja |
| `GET /trips/{trip_id}` | ✅ Usado | `DataService.fetchTrip` — detalle de viaje |
| `GET /stops/{stop_id}/departures?compact=true` | ❌ No usado | Modelo `CompactDepartureResponse` no existe. Pendiente para Widgets. |
| `GET /routes/{route_id}/fares` | ❌ No usado | ROADMAP 3.1. Pendiente formato en API. |
| `GET /operators/{operator_id}/fares` | ❌ No usado | ROADMAP 3.1. CMS fares, datos pendientes. |
| `GET /agencies` | ❌ No usado | Uso interno/admin. |
| `GET /coordinates/lines` | ❌ No usado | No prioritario. |
| `GET /province/{name}/lines` | ❌ No usado | No prioritario. |
| `GET /journey/isochrone` | ❌ No usado | No prioritario. |

## GTFS-RT (`/api/gtfs-rt/`)

| Endpoint | Estado | Dónde se usa |
|----------|--------|-------------|
| `GET /alerts` | ✅ Usado | `DataService.fetchAlertsForStop/Route/Line` — alertas con filtros |
| `GET /alerts?route_id=` | ✅ Usado | `GTFSRealtimeService.fetchAlertsForRoute` |
| `GET /alerts?stop_id=` | ✅ Usado | `GTFSRealtimeService.fetchAlertsForStop` |
| `GET /vehicles/{vehicle_id}` | ✅ Usado | `GTFSRealtimeService.fetchVehicleById` — vehículo individual |
| `GET /platforms/predictions` | ✅ Usado | `DataService.applyPlatformPredictions` — andén estimado |
| `GET /station-occupancy` | ✅ Usado | `StopDetailView.loadData` — ocupación TMB |
| `GET /equipment-status/{stop_id}` | ✅ Usado | `StopDetailView.loadData` — ascensores Metro Sevilla |
| `GET /stats` | ❌ Dead code | Fetch existe pero nunca se llama. |
| `GET /trip-updates` | ❌ Dead code | Fetch existe pero nunca se llama. ROADMAP 3.13. |
| `GET /stops/{stop_id}/realtime` | ❌ Dead code | Fetch existe pero nunca se llama. Legacy/debug. |
| `GET /vehicles` | ❌ Dead code | `fetchEstimatedPositionsForNetwork/Route` existe pero no se llama desde vistas. |
| `GET /occupancy` | ❌ No usado | ROADMAP 3.14. Ocupación por vehículo. |
| `GET /vehicles/{id}/occupancy/per-car` | ❌ No usado | Sin datos consistentes. |
| `GET /stop-time-updates` | ❌ No usado | Duplica departures. |
| `GET /equipment-status/?operator_id=` | ❌ No usado | Bulk. Per-stop ya se usa. |

## Admin (`/api/gtfs-rt/` + token)

| Endpoint | Estado | Dónde se usa |
|----------|--------|-------------|
| `POST /fetch/{operator_id}` | ❌ Dead code | Fetch existe pero nunca se llama. |
| `POST /cleanup` | ❌ Dead code | Fetch existe pero nunca se llama. |
| `GET /admin/dlq` | ❌ No usado | No hay vista admin. |
| `POST /admin/dlq/{id}/retry` | ❌ No usado | |
| `POST /admin/dlq/{id}/dismiss` | ❌ No usado | |
| `GET /admin/dlq/stats` | ❌ No usado | |
| `GET /cache/stats` | ❌ No usado | |
| `POST /cache/invalidate` | ❌ No usado | |

## Resumen

| Categoría | Usados | Dead code | No usados |
|-----------|--------|-----------|-----------|
| GTFS Static | 22 | 0 | 6 |
| GTFS-RT | 6 | 4 | 4 |
| Admin | 0 | 2 | 6 |
| **Total** | **28** | **6** | **16** |

**Dead code** = método fetch existe en `GTFSRealtimeService.swift` pero nunca se llama desde DataService ni vistas:
- `fetchRealtimeStats()` → `/stats`
- `fetchTripUpdates()` → `/trip-updates`
- `fetchStopRealtime()` → `/stops/{id}/realtime`
- `fetchEstimatedPositionsForNetwork/Route()` → `/vehicles`
- `triggerRealtimeFetch()` → `/fetch/{operator_id}`
- `triggerRealtimeCleanup()` → `/cleanup`
