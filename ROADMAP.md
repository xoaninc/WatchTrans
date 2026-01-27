# WatchTrans Roadmap

Documento unificado de features pendientes, bugs y mejoras técnicas.

**Última actualización:** 2026-01-28

---

## 1. FEATURES APP (iOS)

### 1.1 Siri Shortcuts
**Estado:** ✅ COMPLETADO (28 Enero 2026)

**Archivos:**
- `WatchTrans iOS/Intents/NextTrainIntent.swift`
- `WatchTrans iOS/Intents/AppShortcuts.swift`

**Frases configuradas:**
- "Próximo tren en [parada] con WatchTrans"
- "¿Cuándo pasa el tren en [parada]?"
- "Salidas de [parada] con WatchTrans"
- "Horarios de [parada] en WatchTrans"
- "Next train at [stop] with WatchTrans"
- "When is the next train at [stop] with WatchTrans?"
- "Departures from [stop] with WatchTrans"

**Funcionalidades:**
- Búsqueda de paradas por nombre
- Sugerencias automáticas (favoritos, hubs, cercanas)
- Vista snippet con próximas salidas
- Indicador de tiempo real
- Soporte español e inglés

---

### 1.2 Widgets iOS
**Estado:** ⏳ Esperando endpoint `?compact=true` de API

**Dependencia API:**
```
GET /api/v1/gtfs/stops/{stop_id}/departures?compact=true&limit=3
```

**Response esperada:**
```json
{
  "stop_id": "METRO_SOL",
  "stop_name": "Sol",
  "departures": [
    {"line": "L1", "minutes": 3, "headsign": "Valdecarros"}
  ],
  "updated_at": "2026-01-27T15:30:00Z"
}
```

**Requisitos:** <5KB, <500ms latencia

---

### 1.3 Complicaciones Apple Watch
**Estado:** ⏳ Pendiente

**Tipos a implementar:**
- Circular: próxima salida (línea + minutos)
- Rectangular: 2-3 próximas salidas
- Corner: icono + minutos

**Dependencia:** Mismo endpoint compact que widgets

---

### 1.4 Paradas Frecuentes (Auto-detectar)
**Estado:** ✅ Implementado

**Archivos creados:**
- `WatchTrans iOS/Services/FrequentStopsService.swift`

**Funcionalidad:**
- Registra visitas a paradas automáticamente
- Detecta patrones (hora, día de semana, L-V vs fines de semana)
- Muestra sección "Frecuentes" en Home con badge de patrón (ej: "~08:00 L-V")
- Ordena por relevancia según hora actual

---

### 1.5 Abrir en Apple Maps/Google Maps
**Estado:** ✅ Implementado

**Archivos creados:**
- `WatchTrans iOS/Services/MapLauncher.swift`

**Apps soportadas:**
- Apple Maps (siempre disponible)
- Google Maps
- Citymapper
- Waze

**Uso:** Botón en toolbar de StopDetailView → muestra selector de app

---

### 1.6 iCloud Sync para Favoritos
**Estado:** 📋 Documentado, baja prioridad

**Decisión:** Usar SharedStorage (local) + iCloud (sync)

**Arquitectura:**
```
iCloud ←→ SharedStorage ←→ Widget/Siri
```

**Datos a sincronizar:**
- ✅ Favoritos
- ✅ Hub stops
- ❌ Ubicación (sensible)
- ❌ Cache

**Implementación:** Ver sección 7.1

---

## 2. CAMBIOS API PENDIENTES

### 2.1 RAPTOR Routing Engine
**Estado:** ✅ IMPLEMENTADO (27 Enero 2026)

Endpoint: `GET /route-planner?from=X&to=Y&departure_time=HH:MM`

Parámetros:
- `max_transfers` (default: 3)
- `max_alternatives` (default: 3)

Response incluye: `journeys[]`, `departure`, `arrival`, `suggested_heading`, `alerts[]`

---

### 2.2 Route Planner v2
**Estado:** ✅ IMPLEMENTADO

**Endpoint:**
```
GET /api/v1/gtfs/route-planner?from=STOP_ID&to=STOP_ID&departure_time=08:30
```

**Cambios en response:**

| Campo | Antes | Después |
|-------|-------|---------|
| journey | objeto singular | `journeys[]` array 1-3 |
| departure/arrival | no existía | timestamps ISO8601 |
| alerts | no existía | array de alertas |
| suggested_heading | no existía | float 0-360 por segmento |

**Response v2:**
```json
{
  "success": true,
  "journeys": [
    {
      "departure": "2026-01-28T08:32:00",
      "arrival": "2026-01-28T09:07:00",
      "duration_minutes": 35,
      "transfers": 2,
      "walking_minutes": 5,
      "segments": [...]
    }
  ],
  "alerts": [
    {"line_id": "L1", "message": "Frecuencia reducida", "severity": "warning"}
  ]
}
```

---

### 2.3 Departures Compact Endpoint
**Estado:** ⏳ Pendiente (responsable: API)

**Para:** Widgets iOS, Siri Shortcuts, Apple Watch

**Requisitos:**
- Tamaño: <5KB
- Latencia: <500ms

Ver sección 1.2 para detalles.

---

### 2.4 Suggested Heading
**Estado:** ✅ IMPLEMENTADO (27 Enero 2026)

Incluido en cada segmento del route planner response:
```json
{
  "segments": [
    {
      "suggested_heading": 45.5
    }
  ]
}
```

Tipo: `float` (0-360 grados, 0=norte)

---

## 3. BUGS CONOCIDOS

### 3.1 C10 Madrid incluye parada de Zaragoza
**Estado:** ✅ ARREGLADO (27 Enero 2026)

---

### 3.2 Correspondencias Barcelona incompletas
**Estado:** ✅ ARREGLADO (27 Enero 2026)

- Espanya: ✅ conecta con L1, L3
- Diagonal: ✅ conecta con L3, L5, FGC

---

### 3.3 Metro Sevilla sin horarios
**Estado:** ❌ PENDIENTE

**Problema:** Las 21 paradas existen pero departures devuelve vacío.
Falta cargar stop_times (como Metro Granada que tiene 143,098).

**Paradas afectadas:** `METRO_SEV_L1_E1` a `METRO_SEV_L1_E21`

---

### 3.4 Route Planner Metro Madrid
**Estado:** ❌ PENDIENTE

**Problema:** No encuentra rutas entre paradas de Metro Madrid.
Ejemplo: `METRO_12` (Sol) → `METRO_14` (Gran Vía) devuelve "No route found"

---

### 3.3 Bug MapKit: Polyline desaparece con rotación
**Descripción:** Al rotar cámara (heading) en animación 3D, MapKit deja de renderizar polyline

**Workaround actual:** Heading fijo a 0

**Posible solución:** Usar `suggested_heading` de API para transiciones suaves

---

## 4. MODELOS SWIFT A ACTUALIZAR (cuando API v2 esté lista)

### RenfeServerModels.swift
```swift
// ACTUALIZAR
struct RoutePlanResponse: Codable {
    let success: Bool
    let message: String?
    let journeys: [RoutePlanJourney]  // era journey singular
    let alerts: [RouteAlert]?         // NUEVO
}

struct RoutePlanJourney: Codable {
    let departure: String             // NUEVO
    let arrival: String               // NUEVO
    let durationMinutes: Int
    let walkingMinutes: Int
    let transfers: Int
    let segments: [RoutePlanSegment]
}

struct RoutePlanSegment: Codable {
    // ... campos existentes ...
    let suggestedHeading: Double?     // NUEVO
}

// NUEVOS
struct RouteAlert: Codable {
    let lineId: String
    let message: String
    let severity: String  // "info", "warning", "error"
}

struct CompactDeparturesResponse: Codable {
    let stopId: String
    let stopName: String
    let departures: [CompactDeparture]
    let updatedAt: String
}
```

---

## 5. COORDINACIÓN DE DEPLOY

| Paso | Responsable | Estado |
|------|-------------|--------|
| 1. Implementar RAPTOR | API | ⏳ |
| 2. Deploy a staging | API | ⏳ |
| 3. Actualizar modelos Swift | App | ⏳ |
| 4. Testing conjunto | Ambos | ⏳ |
| 5. Deploy producción | API | ⏳ |
| 6. Submit App Store | App | ⏳ |

---

## 6. FEATURES FUTURAS (v2+)

### 6.1 Ticketing / Payment
**Inspiración:** Masabi JustRide SDK

**Features:**
- Compra de billetes in-app
- QR para validación
- Wallet integration

**Prioridad:** Baja (requiere acuerdos con operadores)

---

### 6.2 Bike-share Integration
**Inspiración:** OpenTripPlanner

**Sistemas españoles:**
- BiciMAD (Madrid)
- Bicing (Barcelona)

**API:** GBFS (General Bikeshare Feed Specification)

**Prioridad:** Baja

---

### 6.3 CarPlay
**Inspiración:** Citymapper

**Prioridad:** Baja (complejidad alta)

---

### 6.4 Mapas Offline
**Inspiración:** Moovit (vector tiles)

**Tecnología:** MapLibre + vector tiles

**Prioridad:** Baja

---

### 6.5 Reportar Incidencias
**Inspiración:** OneBusAway (Open311)

**Prioridad:** Baja

---

## 7. DECISIONES TÉCNICAS

### 7.1 Storage: SharedStorage + iCloud

**Arquitectura:**
```
┌─────────────┐     ┌─────────────────┐     ┌─────────────┐
│   iCloud    │ ←→  │  SharedStorage  │ ←→  │ Widget/Siri │
│  (backup)   │     │  (fuente local) │     │    (UI)     │
└─────────────┘     └─────────────────┘     └─────────────┘
```

**Implementación:**
```swift
let iCloudStore = NSUbiquitousKeyValueStore.default

NotificationCenter.default.addObserver(
    forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
    object: iCloudStore,
    queue: .main
) { _ in
    let favorites = iCloudStore.array(forKey: "favorites")
    SharedStorage.shared.saveFavorites(favorites)
}
```

**Límites:** 1MB total, 1KB por clave

---

### 7.2 Real-time: Polling Inteligente

**Decisión:** No WebSockets por ahora

**Estrategia:**
- App activa: polling cada 30s
- App background: polling cada 5min
- Widget: refresh según sistema

---

### 7.3 Routing: RAPTOR (API)

**Decisión:** Migrar de Dijkstra a RAPTOR en servidor

**App no hace routing local** - eliminado RoutingService.swift

---

### 7.4 Cache en App

| Dato | Cachear | TTL |
|------|---------|-----|
| Paradas | ✅ | 1 semana |
| Info líneas | ✅ | 1 semana |
| Rutas buscadas | ✅ | Indefinido |
| Favoritos | ✅ | Indefinido |
| Departures | ❌ | Siempre fresh |
| Route planner | ❌ | Siempre fresh |

---

## 8. REFERENCIAS

### Apps analizadas
- OneBusAway (features)
- Citymapper (CMMapLauncher)
- Moovit (vector tiles, Caishen)

### Librerías útiles
- TripKit (Swift) - proveedores de transporte
- GraphHopper (Java) - routing multimodal
- OpenTripPlanner (Java) - RAPTOR

### Recursos
- GTFS spec: https://gtfs.org
- Transitous (150+ feeds españoles): https://transitous.org
- awesome-transit: https://github.com/CUTR-at-USF/awesome-transit

---

*Documento de planificación WatchTrans*
