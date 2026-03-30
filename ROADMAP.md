# WatchTrans Roadmap

Features pendientes, bugs y mejoras.

**Última actualización:** 2026-03-30

---

## Bugs activos

### Bug MapKit: Polyline desaparece con rotación
Al rotar cámara (heading) en animación 3D, MapKit deja de renderizar polyline.
**Workaround actual:** Heading fijo a 0.
**Posible solución:** Usar `suggested_heading` de la API (ya viene en journey segments).

---

## Endpoints disponibles sin consumir

Endpoints que la API ya ofrece pero la app no usa:

| Endpoint | Qué ofrece | Prioridad |
|----------|-----------|-----------|
| `GET /stops/{id}/facilities` | Facilities de estación (park & ride, atención al cliente, parking bici). Solo Metro Sevilla. | Media |
| `GET /agencies/{id}/policies` | Políticas del operador (mascotas, comida, patinetes, fotos). Solo Metro Sevilla. | Baja |
| `GET /interchanges` + `/{code}` | Hubs de intercambio con paradas agrupadas por código. | Media |
| `GET /coordinates/lines` | Líneas agrupadas cerca de coordenadas (alternativa a routes). | Baja |
| `GET /translations` | Nombres multilingüe GTFS (paradas, rutas). | Baja |
| `GET /transfers` | Tiempos de transbordo entre paradas (para mostrar en correspondencias). | Media |
| `GET /feed-info` | Frescura del feed por operador (para mostrar "datos de hace X"). | Baja |
| `GET /vehicles/{id}/occupancy/per-car` | Ocupación por vagón. FGC y Metro Madrid. | Media |
| `GET /journey/isochrone` | Paradas alcanzables en X minutos desde una parada. | Baja |
| `?compact=true` en departures | Formato ligero para widgets/Siri. Modelo `CompactDepartureResponse` necesario. | Alta |

### Campos disponibles sin consumir

| Campo | Endpoint | Qué es |
|-------|----------|--------|
| `parking_coches` | stops | Parking de coches (Metro Sevilla) |
| `description` | stops | Descripción de la parada (Euskotren, Metro Sevilla, Metro Málaga) |
| `url` | stops | URL de la parada (Metro Tenerife, SFM Mallorca) |
| `agency_name` | `/coordinates/routes`, `/networks/{code}/lines` | Nombre del operador — ya viene en la API, la app no lo consume |
| `suggested_heading` | journey segments | Heading de cámara para animación 3D del journey |

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
