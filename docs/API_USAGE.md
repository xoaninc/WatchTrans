# WatchTrans App — API Usage Map

**Base URL:** `https://api.watch-trans.app`
**Última actualización:** 2026-03-18

Referencia de qué endpoints consume la app y cuáles no.
Fuente de verdad del servidor: `/Users/juanmaciasgomez/Projects/WatchTrans_Server/docs/API_ENDPOINTS.md`

---

## GTFS Static (`/api/gtfs/`)

| Endpoint | Estado | Dónde se usa |
|----------|--------|-------------|
| `GET /stops/by-coordinates` | ✅ | `DataService.fetchTransportData` — carga principal al arrancar |
| `GET /stops/{stop_id}` | ✅ | `DataService.fetchStopDetails` — detalle individual |
| `GET /stops/{stop_id}/departures` | ✅ | `DataService.fetchArrivals` — endpoint principal de salidas |
| `GET /stops/{stop_id}/full` | ✅ | `StopDetailView.loadData` — correspondencias, andenes, accesos, accesibilidad |
| `GET /stops/{stop_id}/platforms` | ✅ | `DataService.fetchPlatforms` — coordenadas de andenes |
| `GET /stops/{stop_id}/accesses` | ✅ | `DataService.fetchAccesses` — bocas de metro (fallback si no hay station-interior) |
| `GET /stops/{stop_id}/station-interior` | ✅ | `StopDetailView.loadData` — pathways, vestíbulos, niveles |
| `GET /stops/{stop_id}/correspondences` | ✅ | `DataService.fetchCorrespondences` — estaciones a pie |
| `GET /stops/{stop_id}/children` | ✅ | `DataService.fetchChildren` — andenes hijos |
| `GET /stops?search=` | ✅ | `DataService.fetchStops` — búsqueda por nombre |
| `GET /routes/{route_id}` | ✅ | `DataService.fetchRouteDetail` — detalle de ruta |
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
| `GET /route-planner/range` | ✅ | `DataService.fetchRoutePlanRange` — rRAPTOR por franja |
| `GET /trips/{trip_id}` | ✅ | `DataService.fetchTrip` — detalle de viaje |
| `GET /stops/{id}/departures?compact=true` | ❌ | Modelo `CompactDepartureResponse` no existe. Pendiente para Widgets. |
| `GET /routes/{route_id}/fares` | ❌ | ROADMAP 3.1. |
| `GET /operators/{operator_id}/fares` | ❌ | ROADMAP 3.1. |
| `GET /agencies` | ❌ | Uso interno. |
| `GET /coordinates/lines` | ❌ | No prioritario. |
| `GET /province/{name}/lines` | ❌ | No prioritario. |
| `GET /journey/isochrone` | ❌ | No prioritario. |

## GTFS-RT (`/api/gtfs-rt/`)

| Endpoint | Estado | Dónde se usa |
|----------|--------|-------------|
| `GET /alerts` | ✅ | `DataService.fetchAlertsForStop/Route/Line` — alertas con filtros |
| `GET /alerts?route_id=` | ✅ | `GTFSRealtimeService.fetchAlertsForRoute` |
| `GET /alerts?stop_id=` | ✅ | `GTFSRealtimeService.fetchAlertsForStop` |
| `GET /vehicles/{vehicle_id}` | ✅ | `GTFSRealtimeService.fetchVehicleById` |
| `GET /platforms/predictions` | ✅ | `DataService.applyPlatformPredictions` — andén estimado |
| `GET /station-occupancy` | ✅ | `StopDetailView.loadData` — ocupación TMB |
| `GET /equipment-status/{stop_id}` | ✅ | `StopDetailView.loadData` — ascensores Metro Sevilla |
| `GET /stats` | ⚠️ Dead code | Fetch existe, nunca se llama |
| `GET /trip-updates` | ⚠️ Dead code | Fetch existe, nunca se llama. ROADMAP 3.13. |
| `GET /stops/{stop_id}/realtime` | ⚠️ Dead code | Fetch existe, nunca se llama. Legacy/debug. |
| `GET /vehicles` | ⚠️ Dead code | Fetch existe, nunca se llama desde vistas |
| `GET /occupancy` | ❌ | ROADMAP 3.14. |
| `GET /vehicles/{id}/occupancy/per-car` | ❌ | Sin datos consistentes. |
| `GET /stop-time-updates` | ❌ | Duplica departures. |
| `GET /equipment-status/?operator_id=` | ❌ | Bulk. Per-stop ya se usa. |

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

| Categoría | ✅ Usados | ⚠️ Dead code | ❌ No usados |
|-----------|-----------|--------------|-------------|
| GTFS Static | 22 | 0 | 6 |
| GTFS-RT | 6 | 4 | 4 |
| Admin | 0 | 2 | 6 |
| **Total** | **28** | **6** | **16** |

## Notas de cambios del backend (2026-03-18)

- `alternative_service_warning` ahora es per-ruta, no per-stop. Solo true cuando hay transporte alternativo REAL.
- `express_color` para CIVIS ahora es `"E95EBE"` (rosa).
- `wheelchair_boarding` arreglado en `/stops/{stop_id}` (antes era siempre null).
- Alertas de accesibilidad ahora solo se asocian a rutas que pasan por la parada afectada.
- `estimated_restoration_time` tipo string (texto humano), no datetime.
- `parking_bicis` ≠ `acerca_service.parking`: el primero es aparcabicis, el segundo parking de coches (solo 56 estaciones).
- Operadores RT: `renfe`, `tmb`, `fgc`, `euskotren`, `metro_bilbao`, `metro_madrid`, `mlo`. Metro Sevilla/Tram Sevilla/Zaragoza solo vía `/departures`.
- Interior source `combined` nuevo para estaciones con datos mixtos.
