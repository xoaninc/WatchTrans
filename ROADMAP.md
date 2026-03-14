# WatchTrans Roadmap

Features pendientes, bugs y mejoras técnicas.

**Última actualización:** 2026-03-14

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
- **3.6 RT completo de parada** — modelo y fetch listos (`StopRealtimeResponse`). Pendiente integrar en DataService como optimización.
- **Alertas por parada** — badges en Home, inline en LineDetailView, sección completa en StopDetailView.

### Metro Sevilla RT ✅

- **Departures** — vehicleLabel, headsigns limpios (KI #170), composición Simple/Doble desde trip_id
- **Equipment status** — ascensores/escaleras con iconos AIGA custom (SVG imageset) y colores verde/rojo. 19 estaciones, ~106 dispositivos. `GET /api/gtfs-rt/equipment-status/{stop_id}`
- **Train position** — `current_stop_name` disponible, recorrido se colorea. Fallback con route stops para trips sintéticos (invertido si headsign = primer stop)
- **Air quality** — modelo y fetch listos. Sin datos de VPs por ahora (feature futura del servidor)
- **Alertas de servicio** — entran como alertas estándar via `/gtfs-rt/alerts?operator_id=metro_sevilla`. Schema noticias: `source=metro_sevilla_news`, `ai_summary` para texto limpio

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

#### 3.4 Interior de estaciones
`GET /api/gtfs/stops/{stop_id}/station-interior`
**Cobertura:** TMB (1,065 pathways), Euskotren (686), SFM Mallorca (30), Renfe Cercanías (195 accesos), Metro Valencia (186). Metro Madrid y ML tienen problemas de resolución.
Aparcado — backend arreglando datos.

### Sin datos / No prioritarios

- **3.2 Ocupación por vagón** — ningún operador envía datos per-car.
- **3.7 Stop-time updates** — duplica funcionalidad de departures.
- **3.9 Mapa isócrono** — requiere UI de mapa nueva.
- **3.10 Líneas por coordenadas** — uso interno.
- **3.11 Agencias** — uso interno.
- **3.12 Detalle de ruta individual** — uso interno.

---

## 4. FEATURES FUTURAS (v2+)

| Feature | Prioridad | Notas |
|---------|-----------|-------|
| Ticketing / Payment | Baja | Requiere acuerdos con operadores (Masabi JustRide SDK) |
| Bike-share (BiciMAD, Bicing) | Baja | GBFS spec |
| CarPlay | Baja | Complejidad alta |
| Mapas Offline | Baja | MapLibre + vector tiles |
| Reportar Incidencias | Baja | Open311 |
