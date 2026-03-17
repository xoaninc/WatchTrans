# WatchTrans Roadmap

Features pendientes, bugs y mejoras técnicas.

**Última actualización:** 2026-03-17

---

## 1. BUGS ACTIVOS

### ~~1.1 Route Planner Metro Madrid~~ ✅ RESUELTO
IDs de Metro Madrid cambiaron con la migración de servidor. Además se añadió `departure_time` automático a todas las llamadas del route planner.

### 1.2 Bug MapKit: Polyline desaparece con rotación
Al rotar cámara (heading) en animación 3D, MapKit deja de renderizar polyline.
**Workaround actual:** Heading fijo a 0.
**Posible solución:** Usar `suggested_heading` de API para transiciones suaves.

---

## 2. FEATURES PENDIENTES

### 2.1 Integrar compact endpoint en Widgets/Siri
Endpoint ya disponible: `GET /api/gtfs/stops/{stop_id}/departures?compact=true&limit=10`
Pendiente usar en Widgets iOS y Siri Shortcuts para respuestas más ligeras.

### 2.2 Push Notifications para Alertas
Notificar cuando una línea favorita tiene incidencias.
- Suscribirse a alertas de líneas favoritas
- Push notification cuando hay incidencia/avería
- Requiere APNs + servidor de notificaciones

### 2.3 Watch Independiente
Apple Watch funciona sin iPhone cerca (WiFi/Cellular propio).
- watchOS independiente con URLSession
- Sincronización de favoritos vía iCloud

---

## 3. ENDPOINTS NUEVOS DISPONIBLES (api.watch-trans.app)

### Implementados ✅

- **3.5 Predicción de andén** — rellenar plataformas vacías con predicción histórica (badge naranja). Ambos targets.
- **3.3 Ocupación de estación TMB** — barras de progreso por andén en StopDetailView (paradas `TMB_METRO_*`).
- **3.8 Búsqueda en rango horario** — toggle "Buscar por franja horaria" en JourneyPlannerView.
- ~~**3.6 RT completo de parada**~~ — endpoint legacy/debug, no usar. La app ya usa `/stops/{id}/departures` que es el correcto.
- **Alertas por parada** — badges en Home, inline en LineDetailView, sección completa en StopDetailView.

### Metro Sevilla RT ✅

- **Departures** — vehicleLabel, headsigns limpios (KI #170), composición Simple/Doble desde trip_id
- **Equipment status** — ascensores/escaleras con iconos AIGA custom (SVG imageset) y colores verde/rojo. 19 estaciones, ~106 dispositivos. `GET /api/gtfs-rt/equipment-status/{stop_id}`
- **Train position** — `current_stop_name` disponible, recorrido se colorea. Fallback con route stops para trips sintéticos (invertido si headsign = primer stop)
- **Air quality** — modelo y fetch listos. Sin datos de VPs por ahora (feature futura del servidor)
- **Alertas de servicio** — entran como alertas estándar via `/gtfs-rt/alerts?operator_id=metro_sevilla`. Schema noticias: `source=metro_sevilla_news`, `ai_summary` para texto limpio

### UI pendiente

- **Selector de líneas del mapa** — cambiar `Menu` por `Sheet`/`Popover` para mostrar logos reales de operador y badges de color por línea (C1, L1, etc.). `Menu` de SwiftUI no permite `Image` custom.
- **Pathways en route planner** — usar `signposted_as` como texto principal cuando existe (es lo que el usuario ve en la estación real), fallback a `from_stop_name → to_stop_name`.

### Pendiente replicar en Watch

- **Metro Sevilla RT** (equipment status, air quality) — solo implementado en iOS. Replicar modelos, fetch y UI en watchOS cuando sea prioritario. vehicleLabel ya replicado.
- **Equipment status en otras redes** — `EquipmentStatusSection` ya es genérico, pero solo Metro Sevilla tiene datos en la API. Metro Madrid y TMB Barcelona devuelven `[]` en equipment-status y accesses. Expandir cuando el backend tenga datos de otras redes.
- **Ocupación estación TMB** — solo iOS.
- ~~**Alertas por parada** (badges en Home/LineDetailView) — solo iOS.~~ ✅ Implementado en watchOS LineDetailView.
- **Búsqueda en rango horario** — solo iOS.

### Pendientes

#### 3.1 Tarifas
`GET /api/gtfs/routes/{route_id}/fares`
**Cobertura:** Euskotren (122), Metro Bilbao (25), Metro Sevilla (54), Metro Granada (1). Resto sin datos.
Pendiente arreglar formato en la API.

#### ~~3.4 Interior de estaciones~~ ✅ IMPLEMENTADO
`StationInteriorSection` muestra accesos, recorridos, vestíbulos y niveles. Reemplaza NearestAccessSectionView cuando hay datos de interior.


#### 3.13 Retrasos de trenes (trip-updates)
`GET /api/gtfs-rt/trip-updates`
**Datos disponibles:** Renfe (~140 registros con `delay` en segundos, `trip_id`, `route_id`).
**Uso:** Dentro de la vista de detalle de trip (al pinchar en un viaje concreto), mostrar retraso con precisión de segundos además de los minutos ya mostrados. Solo en trip detail, no en departures.

#### 3.14 Ocupación de vehículos
`GET /api/gtfs-rt/occupancy`
**Datos disponibles:** FGC envía `occupancy_status` por vehículo (2=FEW_SEATS_AVAILABLE, 7=STANDING_ROOM_ONLY, etc.).
**Uso:** Icono de ocupación en departures/mapa (estilo Google Maps). Mismo concepto que ocupación TMB Metro (station-occupancy) pero a nivel vehículo. Diferente de 3.2 (per-car).

#### 3.19 Estado de servicio de rutas
`GET /api/gtfs/routes/{route_id}` (campos `service_status`, `suspended_since`, `is_alternative_service`)
**Datos disponibles:** La app ya usa sub-endpoints (/stops, /shape, /frequencies) pero no el detalle raíz que contiene estado de servicio.
**Uso:** Badge en LineDetailView si línea suspendida o servicio alternativo.

### Sin datos / No prioritarios

- **3.2 Ocupación por vagón** — ningún operador envía datos per-car.
- **3.7 Stop-time updates** — duplica funcionalidad de departures.
- **3.8b Operators fares** — `GET /api/gtfs/operators/{operator_id}/fares` — sin datos útiles aún (vacío para todos los operadores probados).
- **3.11 Agencias** — uso interno.
- **3.12 Detalle de ruta individual** — parcialmente útil, ver 3.19 para campos específicos.
- **3.15 Equipment status global** — `GET /api/gtfs-rt/equipment-status/` (sin stop_id). Todos los dispositivos de golpe. El per-stop ya se usa. No prioritario.
- **3.16 Líneas por provincia** — `GET /api/gtfs/province/{province}/lines`. No prioritario.
- **3.17 Líneas cercanas por GPS** — `GET /api/gtfs/coordinates/lines`. No prioritario.
- **3.18 Isócrona** — `GET /api/gtfs/journey/isochrone`. No prioritario.

---

## 4. FEATURES FUTURAS (v2+)

| Feature | Prioridad | Notas |
|---------|-----------|-------|
| Ticketing / Payment | Baja | Requiere acuerdos con operadores (Masabi JustRide SDK) |
| Bike-share (BiciMAD, Bicing) | Baja | GBFS spec |
| CarPlay | Baja | Complejidad alta |
| Mapas Offline | Baja | MapLibre + vector tiles |
| Reportar Incidencias | Baja | Open311 |
