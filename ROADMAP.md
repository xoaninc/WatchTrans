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

### ~~1.3 LineResponse CodingKeys desactualizados~~ ✅ RESUELTO

### Bugs backend arreglados (2026-03-18)

Estos bugs los arregló el compañero de la API, no requieren cambios en la app:

- ~~`alternative_service_warning` per-stop en vez de per-ruta~~ ✅ Arreglado (KI #185). Ahora solo true cuando hay transporte alternativo REAL en la ruta del departure.
- ~~`parking_bicis` faltaba en `/routes/{id}/stops`~~ ✅ Arreglado. Badge Parking Bici ahora visible en vista de línea.
- ~~Campos faltantes en `/stops/{id}/full`, `/routes/{id}/stops`, `/routes/{id}`~~ ✅ Arreglado. Badges y estados consistentes en todas las vistas.
- ~~`estimated_restoration_time` tipo datetime en vez de string~~ ✅ Arreglado. DB guarda texto humano.
- ~~`wheelchair_boarding` siempre null en `/stops/{stop_id}`~~ ✅ Arreglado. Faltaba en el SELECT.
- ~~Alertas accesibilidad asociadas a todas las rutas del núcleo~~ ✅ Arreglado. Ahora solo rutas que pasan por la parada.
- ~~17 modelos Pydantic muertos en backend~~ ✅ Eliminados. App ya limpió `NetworkResponse`.

---

## 2. FEATURES PENDIENTES

### 2.1 Integrar compact endpoint en Widgets/Siri
`GET /api/gtfs/stops/{stop_id}/departures?compact=true&limit=10`
Modelo `CompactDepartureResponse` necesario: `line`, `color`, `dest`, `mins`, `plat`, `delay`, `exp`, `skip`, `alt_svc`, `occ_pct`, `occ_status`.

### 2.2 Push Notifications para Alertas
Notificar cuando una línea favorita tiene incidencias. Requiere APNs + servidor.

### 2.3 Watch Independiente
watchOS independiente con URLSession + sincronización de favoritos vía iCloud.

### ~~2.4 Campos nuevos de DepartureResponse~~ ✅ RESUELTO
Modelos sync + UI para express CIVIS y PMR warning.

### ~~2.5 Alertas multi-fase~~ ✅ RESUELTO
`AlertActivePeriod` con fases temporales en `AlertBannerView`.

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
- **Accesibilidad** — `wheelchairBoarding` badge, `wheelchairAccessible` per-tren, `AcercaService` PMR, `pmrWarning` per-departure. Solo iOS.
- **Express CIVIS** — badge con `expressName` + `expressColor` en departures. Solo iOS.
- **Fases de alertas** — `AlertActivePeriod` con fechas y colores por efecto en `AlertBannerView`. Solo iOS.
- **Parking Bici** — badge 🚲 "Parking Bici" en StopDetailView. Solo iOS.
- **Tarifas** — sección de precios por zona en LineDetailView. Solo iOS.
- **Trip updates** — delay preciso (min+seg) en TrainDetailView. Solo iOS.
- **Ocupación de vehículos** — badge FGC en ArrivalRowView. Solo iOS.
- **Servicio alternativo** — label bus en LinesListView. Solo iOS.
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

#### ~~Modelos desactualizados~~ ✅ RESUELTO (Plan A + B)
Todos los modelos sync con la API. Único pendiente: **CompactDepartureResponse** (modelo nuevo para Widgets/Siri, ver 2.1).

#### ~~3.1 Tarifas~~ ✅ IMPLEMENTADO
Sección en LineDetailView con precios por zona. Metro Bilbao (25 tarifas), Metro Sevilla (54), Metro Granada (1).

#### ~~3.13 Retrasos de trenes~~ ✅ IMPLEMENTADO
TrainDetailView muestra delay preciso (min + seg) desde trip-updates cuando disponible.

#### ~~3.14 Ocupación de vehículos~~ ✅ IMPLEMENTADO
Badge de ocupación (verde/amarillo/rojo) en ArrivalRowView para departures FGC.

#### ~~3.19 Estado de servicio de rutas~~ ✅ IMPLEMENTADO
Label "Servicio alternativo" con icono bus en LinesListView cuando `is_alternative_service == true`.

#### 3.20 Campos nuevos de departures (2026-03-18)
- `trip_short_name` — número de tren (ej. "02381"). Solo Renfe Proximidad y Metro Ligero. Mostrar en TrainDetailView.
- `wheelchair_accessible_static` — accesibilidad GTFS estática del tren (1=sí, 2=no). 136K trips. Complementa `wheelchair_accessible` (RT).
- `bikes_allowed` — bicis permitidas (0=no, 1=sí). Badge 🚲 en departures de Metro Sevilla/Granada.

#### 3.21 Zona tarifaria en paradas
- `zone_id` — zona tarifaria (ej. "A", "B1"). Disponible en Euskotren, FGC, TMB, Metro Sevilla, Metro Valencia, Tram Alicante. Mostrar en StopDetailView junto al nombre.

#### 3.22 Nombre de ruta sustituida
- `alternative_for_short_name` — nombre de la ruta que sustituye (ej. "C1"). Mostrar en LinesListView como "Sustituye C1" cuando `is_alternative_service == true`.

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
