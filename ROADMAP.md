# WatchTrans Roadmap

Features pendientes, bugs y mejoras técnicas.

**Última actualización:** 2026-03-18

---

## 1. BUGS ACTIVOS

### ~~1.1 Route Planner Metro Madrid~~ ✅ RESUELTO

### 1.2 Bug MapKit: Polyline desaparece con rotación
Al rotar cámara (heading) en animación 3D, MapKit deja de renderizar polyline.
**Workaround actual:** Heading fijo a 0.
**Posible solución:** Usar `suggested_heading` de API para transiciones suaves.

### 1.3 LineResponse CodingKeys desactualizados
API manda `route_color` / `route_text_color`, modelo usa `color` / `textColor`. Ver KNOWN_ISSUES.

---

## 2. FEATURES PENDIENTES

### 2.1 Integrar compact endpoint en Widgets/Siri
`GET /api/gtfs/stops/{stop_id}/departures?compact=true&limit=10`
Modelo `CompactDepartureResponse` necesario: `line`, `color`, `dest`, `mins`, `plat`, `delay`, `exp`, `skip`, `alt_svc`, `occ_pct`, `occ_status`.

### 2.2 Push Notifications para Alertas
Notificar cuando una línea favorita tiene incidencias. Requiere APNs + servidor.

### 2.3 Watch Independiente
watchOS independiente con URLSession + sincronización de favoritos vía iCloud.

### 2.4 Campos nuevos de DepartureResponse
Añadir a los modelos iOS y Watch: `platform_confidence`, `delay_estimated`, `is_express`, `express_name`, `express_color`, `wheelchair_accessible_now`, `pmr_warning`, `alternative_service_warning`, `station_occupancy_pct`, `station_occupancy_status`, `bearing`/`speed` en train_position. Ver KNOWN_ISSUES para detalle.

### 2.5 Alertas multi-fase (active_periods con effect/phase_description)
Mostrar evolución temporal de alertas (ej. "reducido hasta abril, corte total después"). Campos `effect` y `phase_description` en cada `active_period`.

---

## 3. ENDPOINTS DISPONIBLES (api.watch-trans.app)

### Implementados ✅

- **Departures** — `/stops/{id}/departures` — endpoint principal, hybrid board con RT
- **Predicción de andén** — `/gtfs-rt/platforms/predictions` — badge naranja. Ambos targets.
- **Ocupación de estación TMB** — `/gtfs-rt/station-occupancy` — barras de progreso (paradas `TMB_METRO_*`). Solo iOS.
- **Búsqueda en rango horario** — `/route-planner/range` — rRAPTOR. Solo iOS.
- **Alertas** — `/gtfs-rt/alerts` — con filtros route_id, stop_id, `AlertFilterHelper`, effects GTFS-RT, `AlternativeTransport`
- **Alertas por parada** — badges en Home, inline en LineDetailView, sección en StopDetailView. iOS + Watch.
- **Interior de estaciones** — `/stops/{id}/station-interior` — `StationInteriorSection` con accesos, recorridos, vestíbulos, niveles. Solo iOS.
- **Equipment status** — `/gtfs-rt/equipment-status/{stop_id}` — `EquipmentStatusSection` con iconos AIGA. Solo Metro Sevilla tiene datos. Solo iOS.
- **Accesibilidad** — `wheelchairBoarding` badge, `wheelchairAccessible` per-tren, `AcercaService` PMR. Solo iOS.
- **Vehicle positions** — `/gtfs-rt/vehicles` — mapa de trenes
- **Route planner** — `/route-planner` — RAPTOR journey planning
- **Route shapes** — `/routes/{id}/shape` — polylines para mapa
- **Correspondencias** — `/stops/{id}/correspondences` — estaciones cercanas a pie
- **Plataformas** — `/stops/{id}/platforms` — coordenadas de andenes
- **Accesos** — `/stops/{id}/accesses` — bocas de metro (fallback cuando no hay station-interior)

### Metro Sevilla RT ✅

- **Departures** — vehicleLabel, headsigns limpios, composición Simple/Doble, dirección fallback
- **Equipment status** — iconos AIGA, verde/rojo. 19 estaciones, ~106 dispositivos
- **Train position** — `current_stop_name`/`current_stop_id`, recorrido se colorea
- **Alertas** — estándar via `/gtfs-rt/alerts?operator_id=metro_sevilla`

### UI pendiente

- **Selector de líneas del mapa** — cambiar `Menu` por `Sheet`/`Popover` con logos y badges de color
- **Pathways en route planner** — `signposted_as` como texto principal

### Pendiente replicar en Watch

- **Metro Sevilla RT** (equipment status) — solo iOS. vehicleLabel ya replicado.
- **Ocupación estación TMB** — solo iOS.
- **Búsqueda en rango horario** — solo iOS.
- **Interior de estaciones** — solo iOS.
- **Accesibilidad** (badges, Acerca PMR) — solo iOS.

### Pendientes de integrar

#### Modelos desactualizados (ver KNOWN_ISSUES para detalle)
- **LineResponse** CodingKeys: `color` → `route_color`, `textColor` → `route_text_color`
- **DepartureResponse** campos nuevos: `is_express`, `express_name`, `pmr_warning`, `alternative_service_warning`, `wheelchair_accessible_now`, `platform_confidence`, `delay_estimated`, `bearing`/`speed`
- **CompactDepartureResponse** modelo nuevo necesario para Widgets/Siri
- **AlertResponse active_periods** con `effect` y `phase_description` por fase
- **AcercaService** falta `source`
- **RouteShapeResponse** falta `is_circular`
- **PlatformPredictionResponse** verificar `sample_size` vs `observation_count`

#### 3.1 Tarifas
`GET /api/gtfs/routes/{route_id}/fares` — GTFS fares (Euskotren 122, Metro Bilbao 25, Metro Sevilla 54). Campos: `route_id`, `currency`, `payment_method`, `transfers_allowed`, `fares[{price, origin_zone, destination_zone}]`.
`GET /api/gtfs/operators/{operator_id}/fares` — CMS fares con `fare_code`, `fare_name`, `price`, `zones`, `age_category`, `periodicity`, `large_family`, `travel_limit`.

#### 3.13 Retrasos de trenes (trip-updates)
`GET /api/gtfs-rt/trip-updates` — retraso con precisión de segundos. Campos: `delay`, `vehicle_id`, `trip_info`. Ordenados por retraso desc.

#### 3.14 Ocupación de vehículos
`GET /api/gtfs-rt/occupancy` — ocupación por vehículo. Campos: `vehicle_id`, `occupancy_status`, `occupancy_percentage`, `occupancy_status_label`, coords. FGC envía datos.

#### 3.19 Estado de servicio de rutas
`GET /api/gtfs/routes/{route_id}` — `service_status`, `suspended_since`, `is_alternative_service`. Incluye `stops[]` y `frequencies[]` inline. Agency como objeto `{id, name}`.

### Particularidades por operador (info nueva del API doc)

| Operador | Notas para la app |
|---|---|
| **Renfe** | 3 prefijos (`RENFE_C_`, `RENFE_FEVE_`, `RENFE_PROX_`). Express CIVIS (`is_express`). PMR Tipo B alerts. FEVE León incluye buses (route_type=3). |
| **TMB** | Tablero híbrido. Único con `station_occupancy`. Trip IDs sintéticos. Filtra solo metro+funicular. |
| **FGC** | Ocupación por vagón (`per-car`). Límite 5,000 req/día. |
| **Metro Madrid** | Estaciones COMPLEX (padre → sub-estaciones). Interior fuente `crtm_extensions`. Tablero híbrido. |
| **Euskotren** | IDs con trailing colon (URL-encode `%3A`). Headsign triple fuente (SIRI ET → NeTEx → última parada). Interior `gtfs_pathways`. |
| **Metro Bilbao** | Interior limitado (`gtfs_entrances`, solo bocas). Colores: L1=#1F1E21, L2=#F1592A, L3=#D10074. |
| **Metro Sevilla** | Equipment status (TCE). Shapes NAP parcheados. API Cloudflare (proxy FlareSolverr). |
| **Tranvía Zaragoza** | Basado en ETA (75s). Posición inferida de ETAs. |

### Lógica de departures (referencia del API doc)

- **Hybrid boards**: TMB, Metro Madrid, ML, Metro Sevilla, Tram Sevilla, Tranvía Zaragoza — RT primero, estático rellena con buffer 120s
- **Overlay**: Renfe, Euskotren, FGC, Metro Bilbao — retrasos/andenes RT sobre horario estático
- **Headsign cascada**: Euskotren SIRI ET → DB → última parada → `route_short_name`
- **Andén cascada**: RT directo → historial (stop, route, headsign) → historial (stop, route)
- **CIVIS**: headsign descartado por el server, usa última parada. `is_express=true`, `express_name="CIVIS"`

### Sin datos / No prioritarios

- **Ocupación por vagón** — `GET /api/gtfs-rt/vehicles/{id}/occupancy/per-car` — FGC/Metro Madrid.
- **Stop-time updates** — `GET /api/gtfs-rt/stop-time-updates` — duplica departures.
- **Agencias** — `GET /api/gtfs/agencies` — uso interno.
- **Equipment status bulk** — `GET /api/gtfs-rt/equipment-status/?operator_id=` — per-stop ya se usa.
- **Líneas por provincia** — `GET /api/gtfs/province/{province}/lines` — no prioritario.
- **Líneas por coordenadas** — `GET /api/gtfs/coordinates/lines` — no prioritario.
- **Isócrona** — `GET /api/gtfs/journey/isochrone` — no prioritario.
- **RT completo de parada** — `GET /api/gtfs-rt/stops/{id}/realtime` — legacy/debug.
- **Children** — `GET /api/gtfs/stops/{id}/children` — ya implementado en fetch.

---

## 4. FEATURES FUTURAS (v2+)

| Feature | Prioridad | Notas |
|---------|-----------|-------|
| Ticketing / Payment | Baja | Requiere acuerdos con operadores (Masabi JustRide SDK) |
| Bike-share (BiciMAD, Bicing) | Baja | GBFS spec |
| CarPlay | Baja | Complejidad alta |
| Mapas Offline | Baja | MapLibre + vector tiles |
| Reportar Incidencias | Baja | Open311 |
