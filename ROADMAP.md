# WatchTrans Roadmap

Features pendientes, bugs y mejoras.

**Última actualización:** 2026-03-30

---

## Bugs activos

### Bug MapKit: Polyline desaparece con rotación
Al rotar cámara (heading) en animación 3D, MapKit deja de renderizar polyline.
**Workaround actual:** Heading fijo a 0.
**Posible solución:** Usar `suggested_heading` de API para transiciones suaves.

---

## Features pendientes

### Compact endpoint en Widgets/Siri
`GET /api/gtfs/stops/{stop_id}/departures?compact=true&limit=10`
Modelo `CompactDepartureResponse` necesario. Permite widgets más ligeros y Siri Shortcuts.

### Push Notifications para Alertas
Notificar cuando una línea favorita tiene incidencias. Requiere APNs + servidor.

### Watch Independiente
watchOS independiente con URLSession + sincronización de favoritos vía iCloud.

### Zona tarifaria en paradas
`zone_id` disponible en Euskotren, FGC, TMB, Metro Sevilla, Metro Valencia, Tram Alicante. Mostrar en StopDetailView.

### Mapa de vehículos en tiempo real
`destination` campo en `/vehicles`. Pins en mapa RT con label "→ Luis de Morales". Requiere nueva vista.

### Detalles de transporte alternativo en alertas
`alternative_transport[]` tiene `type`, `route`, `frequency_minutes`. App solo usa boolean, no muestra detalles.

### Contenido rico en alertas Metro Sevilla
`content` (HTML) e `image_url` en alertas de noticias. Baja prioridad.

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
