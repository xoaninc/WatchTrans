# API Changes v2 - Coordinación App/Backend

Fecha: 2026-01-27
Estado: Pendiente de implementación

---

## RESUMEN DE DECISIONES

| Tema | Decisión |
|------|----------|
| Routing Engine | RAPTOR (sin Transitous fallback) |
| Real-time | Polling inteligente (rápido activo, lento background) |
| Datos | Solo nuestra API |
| Alertas en rutas | Incluidas en route-planner |
| Favoritos | Cliente solo (sin sync servidor) |
| Bike-share | Dejado para v2 |

---

## 1. ROUTE PLANNER - BREAKING CHANGE

### Request
```
GET /api/v1/gtfs/route-planner?from=STOP_ID&to=STOP_ID&departure_time=08:30
```

**Nuevo parámetro:**
- `departure_time` - Formato HH:MM o ISO8601. Si no se pasa, usa hora actual.

### Response ANTES
```json
{
  "success": true,
  "journey": { ... },
  "alternatives": []
}
```

### Response DESPUÉS
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
      "segments": [
        {
          "type": "transit",
          "transport_mode": "metro",
          "line_id": "METRO_SEV_L1",
          "line_name": "L1",
          "line_color": "#ED1C24",
          "headsign": "Olivar de Quintos",
          "origin": { "id": "...", "name": "...", "lat": 0.0, "lon": 0.0 },
          "destination": { "id": "...", "name": "...", "lat": 0.0, "lon": 0.0 },
          "intermediate_stops": [...],
          "duration_minutes": 15,
          "coordinates": [...],
          "suggested_heading": 45.0
        },
        {
          "type": "walking",
          "transport_mode": "walking",
          "origin": { ... },
          "destination": { ... },
          "duration_minutes": 3,
          "distance_meters": 200,
          "coordinates": [...],
          "suggested_heading": 90.0
        }
      ]
    },
    { ... },
    { ... }
  ],
  "alerts": [
    {
      "line_id": "METRO_SEV_L1",
      "message": "Frecuencia reducida",
      "severity": "warning"
    }
  ]
}
```

### Cambios clave
| Campo | Antes | Después |
|-------|-------|---------|
| journey | objeto singular | `journeys[]` array de 1-3 |
| departure/arrival | no existía | timestamps ISO8601 |
| alerts | no existía | array de alertas afectadas |
| suggested_heading | no existía | float 0-360 grados por segmento |

---

## 2. DEPARTURES COMPACT (Widget/Siri)

### Request
```
GET /api/v1/gtfs/stops/{stop_id}/departures?compact=true&limit=3
```

### Response
```json
{
  "stop_id": "METRO_SOL",
  "stop_name": "Sol",
  "departures": [
    {"line": "L1", "minutes": 3, "headsign": "Valdecarros"},
    {"line": "L2", "minutes": 5, "headsign": "Las Rosas"},
    {"line": "L3", "minutes": 2, "headsign": "Moncloa"}
  ],
  "updated_at": "2026-01-27T15:30:00Z"
}
```

### Requisitos
- Tamaño: <5KB
- Latencia: <500ms (crítico para Siri)

---

## 3. SUGGESTED_HEADING

**Propósito:** Dirección de cámara para animación 3D del viaje.

**Formato:**
- Tipo: `float`
- Rango: 0-360 grados
- Referencia: 0=norte, 90=este, 180=sur, 270=oeste

**Uso en app:**
```swift
// Transición suave de cámara entre segmentos
let heading = segment.suggestedHeading ?? 0
mapPosition = .camera(MapCamera(
    centerCoordinate: coord,
    distance: altitude,
    heading: heading,
    pitch: pitch
))
```

---

## 4. CACHE RECOMENDADO EN APP

| Dato | Cachear | TTL |
|------|---------|-----|
| Lista de paradas | ✅ | 1 semana |
| Info de líneas (colores, nombres) | ✅ | 1 semana |
| Últimas rutas buscadas | ✅ | Indefinido (local) |
| Favoritos | ✅ | Indefinido (local) |
| Departures | ❌ | Siempre fresh |
| Route planner | ❌ | Siempre fresh |

---

## 5. MODELOS SWIFT A ACTUALIZAR

### RenfeServerModels.swift

```swift
// ACTUALIZAR RoutePlanResponse
struct RoutePlanResponse: Codable {
    let success: Bool
    let message: String?
    let journeys: [RoutePlanJourney]  // CAMBIO: era journey singular
    let alerts: [RouteAlert]?         // NUEVO
}

// ACTUALIZAR RoutePlanJourney
struct RoutePlanJourney: Codable {
    let departure: String             // NUEVO: ISO8601
    let arrival: String               // NUEVO: ISO8601
    let durationMinutes: Int          // RENOMBRADO: era totalDurationMinutes
    let walkingMinutes: Int           // RENOMBRADO: era totalWalkingMinutes
    let transfers: Int                // RENOMBRADO: era transferCount
    let segments: [RoutePlanSegment]
    // ELIMINADOS: origin, destination (están en segments)

    enum CodingKeys: String, CodingKey {
        case departure, arrival, segments, transfers
        case durationMinutes = "duration_minutes"
        case walkingMinutes = "walking_minutes"
    }
}

// ACTUALIZAR RoutePlanSegment
struct RoutePlanSegment: Codable {
    let type: String
    let transportMode: String
    let lineId: String?
    let lineName: String?
    let lineColor: String?
    let headsign: String?
    let origin: RoutePlanStop
    let destination: RoutePlanStop
    let intermediateStops: [RoutePlanStop]?
    let durationMinutes: Int
    let distanceMeters: Int?
    let coordinates: [RoutePlanCoordinate]
    let suggestedHeading: Double?     // NUEVO

    enum CodingKeys: String, CodingKey {
        case type, origin, destination, coordinates, headsign
        case transportMode = "transport_mode"
        case lineId = "line_id"
        case lineName = "line_name"
        case lineColor = "line_color"
        case intermediateStops = "intermediate_stops"
        case durationMinutes = "duration_minutes"
        case distanceMeters = "distance_meters"
        case suggestedHeading = "suggested_heading"
    }
}

// NUEVO: RouteAlert
struct RouteAlert: Codable {
    let lineId: String
    let message: String
    let severity: String  // "info", "warning", "error"

    enum CodingKeys: String, CodingKey {
        case lineId = "line_id"
        case message, severity
    }
}

// NUEVO: CompactDeparturesResponse (para widgets/Siri)
struct CompactDeparturesResponse: Codable {
    let stopId: String
    let stopName: String
    let departures: [CompactDeparture]
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case stopId = "stop_id"
        case stopName = "stop_name"
        case departures
        case updatedAt = "updated_at"
    }
}

struct CompactDeparture: Codable {
    let line: String
    let minutes: Int
    let headsign: String
}
```

---

## 6. SERVICIOS A ACTUALIZAR

### GTFSRealtimeService.swift

```swift
// ACTUALIZAR fetchRoutePlan
func fetchRoutePlan(
    fromStopId: String,
    toStopId: String,
    departureTime: String? = nil  // NUEVO parámetro
) async throws -> RoutePlanResponse {
    var urlString = "\(baseURL)/route-planner?from=\(fromStopId)&to=\(toStopId)"
    if let time = departureTime {
        urlString += "&departure_time=\(time)"
    }
    // ...
}

// NUEVO: fetchDeparturesCompact
func fetchDeparturesCompact(
    stopId: String,
    limit: Int = 3
) async throws -> CompactDeparturesResponse {
    let urlString = "\(baseURL)/stops/\(stopId)/departures?compact=true&limit=\(limit)"
    // ...
}
```

### DataService.swift

```swift
// ACTUALIZAR planJourney - ahora devuelve array
func planJourney(
    fromStopId: String,
    toStopId: String,
    departureTime: String? = nil
) async -> [Journey]? {
    // Convertir journeys[] a [Journey]
}

// NUEVO: para widgets/Siri
func fetchQuickDepartures(stopId: String) async -> CompactDeparturesResponse? {
    // Wrapper simple para widgets
}
```

---

## 7. VISTAS A ACTUALIZAR

### JourneyPlannerView.swift
- Mostrar múltiples alternativas de ruta
- Mostrar alertas de líneas afectadas
- Añadir selector de hora de salida (opcional)

### Journey3DAnimationView.swift
- Usar `suggestedHeading` para transiciones de cámara
- Eliminar heading fijo

---

## 8. COORDINACIÓN DE DEPLOY

1. **API**: Implementa RAPTOR + cambios
2. **API**: Avisa cuando esté en staging
3. **APP**: Actualiza modelos y prueba contra staging
4. **API**: Deploy a producción
5. **APP**: Submit a App Store

---

## 9. TIMELINE ESTIMADO

| Fase | Responsable | Estado |
|------|-------------|--------|
| Documentación | App | ✅ Completado |
| Implementar RAPTOR | API | ⏳ Pendiente |
| Actualizar modelos Swift | App | ⏳ Esperando API |
| Testing en staging | Ambos | ⏳ Pendiente |
| Deploy coordinado | Ambos | ⏳ Pendiente |

---

*Documento de coordinación App/API*
*Última actualización: 2026-01-27*
