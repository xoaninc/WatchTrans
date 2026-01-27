# Investigación de Apps de Transporte Público

Fecha: 2026-01-27
Tipo: Documento de referencia (solo lectura)

> **Nota:** Las features pendientes y decisiones técnicas están en `ROADMAP.md`

---

## 1. APPS DE REFERENCIA

### OneBusAway (Android/iOS) - El más completo open source
**Repo:** https://github.com/OneBusAway/onebusaway-android

**Features destacadas:**
- Tracking automático de paradas/rutas frecuentes
- Shortcuts en home screen para acceso rápido
- Recordatorios de salida (departure reminders)
- Mapa navegable de paradas cercanas
- Planificación multimodal con bike-share (OpenTripPlanner)
- Reportar incidencias via Open311
- Multi-región (soporte para múltiples ciudades)

**Tecnología:** Java/Kotlin, integra con OpenTripPlanner

**Ideas para WatchTrans:**
- [ ] Siri Shortcuts para paradas favoritas
- [ ] Complicaciones Apple Watch
- [ ] Auto-detectar paradas frecuentes
- [ ] Widgets iOS 17+ interactivos

---

### Citymapper
**Repo:** https://github.com/citymapper

**Repos públicos interesantes:**
- `pygtfs` - Parser de GTFS en Python
- `CMMapLauncher` - iOS library para abrir múltiples apps de mapas
- `sdk-samples` (Swift) - Ejemplos de su SDK de navegación

**Ideas para WatchTrans:**
- [ ] Soporte para abrir en Apple Maps/Google Maps/Citymapper
- [ ] Integración con CarPlay

---

### Moovit
**Repo:** https://github.com/moovit

**Repos públicos (mayormente forks):**
- `graphhopper` - Motor de routing con soporte GTFS
- `flatmap` - Generador de vector tiles desde OSM
- `tileserver-gl` - Renderizado de mapas con estilos GL
- `Caishen` - UI de pago para iOS (Swift)

**Tecnología destacada:**
- GraphHopper para routing multimodal
- Vector tiles para mapas offline

**Ideas para WatchTrans:**
- [ ] Mapas offline con vector tiles
- [ ] Routing alternativo con GraphHopper

---

## 2. LIBRERÍAS Y HERRAMIENTAS

### TripKit (Swift)
**Repo:** https://github.com/alexander-albers/tripkit

**Qué es:** Librería Swift para consultar proveedores de transporte público

**API:**
```swift
protocol NetworkProvider {
    func suggestLocations(query: String) async -> [Location]
    func queryNearbyLocations(lat: Double, lon: Double) async -> [Location]
    func queryDepartures(stationId: String) async -> [Departure]
    func queryTrips(from: Location, to: Location) async -> [Trip]
}
```

**Soporta:** iOS 12+, watchOS 5+, tvOS 12+, macOS 10.13+

**Limitación:** No tiene proveedores españoles (oportunidad de contribuir)

---

### GraphHopper
**Repo:** https://github.com/graphhopper/graphhopper

**Qué es:** Motor de routing open source en Java

**Features:**
- Algoritmos: Dijkstra, A*, Contraction Hierarchies
- Soporte GTFS para transporte público
- Routing multimodal (walk + transit + bike)
- Instrucciones turn-by-turn en 45+ idiomas
- Isócronas (áreas alcanzables en X minutos)
- Map matching (snap GPS a carreteras)

**Uso:** Puede ser alternativa/complemento a nuestro route-planner API

---

### OpenTripPlanner (OTP)
**Repo:** https://github.com/opentripplanner/OpenTripPlanner

**Qué es:** Planificador de viajes multimodal

**Features:**
- Combina GTFS + OpenStreetMap + bike-share
- Alertas en tiempo real integradas en rutas
- API GraphQL
- Soporta múltiples modos: bus, tren, bici, andando, ride-hailing

**Ideas para WatchTrans:**
- [ ] Integrar alertas de servicio en rutas planificadas
- [ ] Añadir bike-share (BiciMAD, Bicing) como modo

---

### R5 (Rapid Realistic Routing)
**Repo:** https://github.com/conveyal/r5

**Qué es:** Motor de routing de Conveyal para análisis de accesibilidad

**Features:**
- Routing multimodal optimizado
- Análisis de ventanas de tiempo
- Usado para planificación urbana

---

## 3. HERRAMIENTAS GTFS

### Validación y Testing
| Herramienta | Descripción | URL |
|-------------|-------------|-----|
| gtfs-realtime-validator | Validador oficial de feeds GTFS-RT | github.com/MobilityData |
| Transport Validator | Validador en Rust (usado en Francia) | - |
| GTFS Display | Análisis y mantenimiento de GTFS | - |

### Conversión y Visualización
| Herramienta | Descripción |
|-------------|-------------|
| gtfs-to-html | Genera horarios HTML/PDF desde GTFS |
| gtfs-to-geojson | Convierte shapes/stops a GeoJSON |
| transit_model (Rust) | Convierte entre GTFS, NeTEx, TransXChange |

### Tiempo Real
| Herramienta | Descripción |
|-------------|-------------|
| gtfsrdb | Archiva datos RT en base de datos |
| gtfs-tripify | Convierte updates RT a datos históricos |
| gtfs-rt-inspector | Web app para inspeccionar feeds RT |

---

## 4. AGREGADORES DE DATOS

### Transitland Atlas
**Repo:** https://github.com/transitland/transitland-atlas

**Qué es:** Catálogo abierto de feeds GTFS mundiales

**Incluye:**
- GTFS (horarios estáticos)
- GTFS-Realtime (posiciones en vivo)
- GBFS (bike-share)
- MDS (micromobility)

**Útil para:** Descubrir qué feeds públicos existen en España

---

### awesome-transit
**Repo:** https://github.com/CUTR-at-USF/awesome-transit

**Qué es:** Lista curada de recursos de transporte público

**Incluye:**
- APIs y datasets
- Apps y herramientas
- Investigación académica
- Software open source

---

## 5. IDEAS PRIORIZADAS PARA WATCHTRANS

### Alta Prioridad
| Feature | Inspiración | Complejidad |
|---------|-------------|-------------|
| Siri Shortcuts "¿Cuándo pasa mi tren?" | OneBusAway | Media |
| Widget iOS interactivo | OneBusAway | Media |
| Complicación Apple Watch | OneBusAway | Media |
| Paradas frecuentes auto-detectadas | OneBusAway | Alta |

### Media Prioridad
| Feature | Inspiración | Complejidad |
|---------|-------------|-------------|
| Abrir en Apple Maps/Google Maps | CMMapLauncher | Baja |
| Alertas integradas en rutas | OpenTripPlanner | Media |
| Mapas offline (vector tiles) | Moovit | Alta |

### Baja Prioridad (futuro)
| Feature | Inspiración | Complejidad |
|---------|-------------|-------------|
| Integración BiciMAD/Bicing | OpenTripPlanner | Alta |
| Reportar incidencias | OneBusAway/Open311 | Media |
| CarPlay | Citymapper | Alta |
| Contribuir proveedor español a TripKit | TripKit | Alta |

---

## 6. ARQUITECTURA DE REFERENCIA

### Stack típico de app de transporte:

```
┌─────────────────────────────────────────┐
│           Mobile App (iOS)              │
│  - SwiftUI / UIKit                      │
│  - MapKit / Google Maps SDK             │
│  - CoreLocation                         │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│           API Backend                    │
│  - GTFS Static (horarios)               │
│  - GTFS-RT (tiempo real)                │
│  - Route Planner (Dijkstra/RAPTOR)      │
│  - Alerts & Service Updates             │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│         Data Sources                     │
│  - Renfe GTFS feeds                     │
│  - Metro/TMB/FGC feeds                  │
│  - OpenStreetMap (walking/cycling)      │
│  - Bike-share APIs (GBFS)               │
└─────────────────────────────────────────┘
```

### Algoritmos de routing:

| Algoritmo | Uso | Complejidad |
|-----------|-----|-------------|
| Dijkstra | Básico, funcional | O(V²) o O(E log V) |
| A* | Más rápido con heurística | O(E log V) |
| RAPTOR | Optimizado para transit | O(K × R × T) |
| Contraction Hierarchies | Pre-procesado, muy rápido | O(log V) queries |

**Nota:** Nuestro API usa Dijkstra. RAPTOR sería más eficiente para transit puro.

---

## 7. RECURSOS ADICIONALES

### Documentación GTFS
- Especificación: https://gtfs.org
- GTFS-RT: https://gtfs.org/realtime

### Comunidades
- GTFS Changes Google Group
- GTFS Realtime Google Group
- MobilityData Slack

### Feeds españoles conocidos
- Renfe Cercanías (múltiples núcleos)
- TMB Metro Barcelona
- Metro Madrid
- FGC
- Metrovalencia
- Metro Bilbao
- Metro Sevilla

---

## 8. DESCUBRIMIENTOS ADICIONALES

### Transitous - Routing internacional con datos españoles
**Repo:** https://github.com/public-transport/transitous
**Web:** https://transitous.org
**Stars:** 536

**Qué es:** Servicio de routing de transporte público internacional, operado por la comunidad.

**Feeds españoles incluidos (150+):**

| Categoría | Operadores |
|-----------|------------|
| **Cercanías** | Renfe (todos los núcleos) |
| **Metro** | Madrid, Barcelona (TMB), Bilbao, Valencia, Málaga, Granada, Sevilla, Tenerife |
| **FGC** | Ferrocarrils de la Generalitat |
| **Euskotren** | País Vasco |
| **Tranvía** | Múltiples ciudades |
| **Bus urbano** | TMB, Bilbobus, Bizkaibus, EMT, etc. |
| **Bus interurbano** | ALSA, Ouigo, regionales |
| **Ferry** | Baleària, Fred. Olsen |

**API gratuita:** Sí, disponible para apps de terceros

**Integraciones:** KDE Itinerary, GNOME Maps, Railway app

**Ideas para WatchTrans:**
- [ ] Usar Transitous como fallback/alternativa a nuestra API
- [ ] Comparar datos con los nuestros para validación
- [ ] Contribuir mejoras a sus feeds españoles

---

### Public Transport Enabler (Java)
**Repo:** https://github.com/schildbach/public-transport-enabler
**Stars:** 429 | **Commits:** 2,634

**Qué es:** Librería Java original en la que se basa TripKit (Swift)

**Protocolos soportados:**
- HAFAS (usado por DB, ÖBB, SBB)
- EFA (usado por muchos operadores alemanes)
- Navitia

**Proveedores españoles:** ❌ No hay implementación española

**Oportunidad:** Contribuir proveedor español (Renfe, TMB, Metro Madrid)

---

### thePublicTransport (Flutter)
**Repo:** https://github.com/nickshanks/tripkit (buscar el de Flutter)
**Stars:** 46

**Qué es:** Primera app de transporte público en Flutter

**Features:**
- Cross-platform (iOS + Android)
- Bus, tren, tranvía, metro
- Enfoque en movilidad sostenible

---

### Kiel-Live (Go + Vue.js)
**Repo:** https://github.com/kiel-live/kiel-live
**Stars:** 43

**Qué es:** PWA de transporte en tiempo real

**Stack:**
- Backend: Go
- Frontend: Vue.js
- Real-time updates

**Ideas para WatchTrans:**
- [ ] Considerar PWA como complemento a la app nativa

---

## 9. COMPARATIVA DE ROUTING ENGINES

| Motor | Lenguaje | Algoritmo | GTFS | Multimodal | Licencia |
|-------|----------|-----------|------|------------|----------|
| **Nuestra API** | Python | Dijkstra | ✅ | ✅ | Privado |
| **Transitous** | ? | ? | ✅ | ✅ | Open |
| **GraphHopper** | Java | CH + A* | ✅ | ✅ | Apache 2.0 |
| **OpenTripPlanner** | Java | RAPTOR | ✅ | ✅ | LGPL |
| **R5** | Java | RAPTOR | ✅ | ✅ | MIT |

**Nota sobre RAPTOR:** Round-Based Public Transit Routing Algorithm - más eficiente que Dijkstra para transit porque explota la estructura de horarios.

---

## 10. GUÍAS DE DESARROLLO Y ARQUITECTURA

### PubNub - Arquitectura Real-Time Transit
**Fuente:** pubnub.com/blog

**Stack recomendado:**
```
┌─────────────────────────────────────┐
│         Cliente (Mobile/Web)        │
│  - HTML5 Geolocation API            │
│  - Google Maps / MapKit             │
│  - PubNub SDK (real-time)           │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│         PubNub (Real-time)          │
│  - Channels por línea/parada        │
│  - Broadcast de ubicaciones         │
│  - Push notifications               │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│         Backend (Node.js)           │
│  - ngeohash (proximity matching)    │
│  - xml2js (parse GTFS feeds)        │
│  - request (HTTP calls)             │
└─────────────────────────────────────┘
```

**Patrón de datos:**
1. Fetch datos de estaciones via API pública (GTFS)
2. Convertir coordenadas a geohash para matching de proximidad
3. Asociar ubicación usuario con estaciones cercanas
4. Obtener horarios en tiempo real
5. Mostrar en mapa interactivo

**Ideas para WatchTrans:**
- [ ] Usar geohash para búsqueda eficiente de paradas cercanas
- [ ] WebSockets/SSE para updates en tiempo real (alternativa a polling)

---

### Online Public Transport Booking (MERN Stack)
**Repo:** https://github.com/roberanegussie/Online-Public-Transport-Booking

**Stack:** MongoDB + Express + React + Node.js + React Native

**Arquitectura multi-rol:**
| App | Plataforma | Funcionalidades |
|-----|------------|-----------------|
| **Usuario** | React Native | Registro, búsqueda rutas, compra tickets, QR |
| **Conductor** | React Native | Horarios, validar QR, comunicación |
| **Admin** | React Web | Gestión usuarios/conductores |
| **Agente** | React Web | Gestión rutas, feedback |

**Ideas para WatchTrans:**
- [ ] Sistema de tickets con QR (para compra integrada)
- [ ] Portal admin para gestión de datos

---

### Public Transport App (Flutter UI)
**Repo:** https://github.com/Yomna-J/public_transport_app_Flutter

**Qué es:** Demo de UI para app de transporte en Flutter

**Flujo de usuario:**
1. Home → Info cuenta + opciones transporte
2. Selección → Página de horarios
3. Horario → Detalles viaje (origen, destino, precio)
4. Compra → Ticket

**Valor:** Referencia de UI/UX para diseño de flujos

---

## 11. ALGORITMO RAPTOR (Para el equipo API)

**RAPTOR** = Round-Based Public Transit Routing Algorithm

**Por qué es mejor que Dijkstra para transit:**
- Dijkstra trata cada conexión como arista genérica
- RAPTOR explota la estructura de horarios (trips, transfers)
- Complejidad: O(K × R × T) donde K=rondas, R=rutas, T=stops

**Concepto clave - Rondas:**
```
Ronda 0: Paradas accesibles desde origen (andando)
Ronda 1: Paradas alcanzables con 1 viaje en transporte
Ronda 2: Paradas alcanzables con 1 transbordo
Ronda N: Paradas alcanzables con N-1 transbordos
```

**Implementaciones open source:**
- OpenTripPlanner (Java)
- R5 by Conveyal (Java)
- minotor (JavaScript) - lightweight

**Recomendación:** Considerar migrar nuestra API de Dijkstra a RAPTOR para mejor rendimiento en redes grandes.

---

*Documento de referencia - ver `ROADMAP.md` para tareas pendientes*
