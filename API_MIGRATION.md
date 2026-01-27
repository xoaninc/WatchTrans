# Migración de Lógica de App a API

## Resumen de Cambios Pendientes

Este documento describe la funcionalidad que actualmente está en la app iOS y que podría/debería moverse al servidor para simplificar el cliente.

---

## 0. ALGORITMO COMPLETO DE BÚSQUEDA DE RUTAS (RoutingService.swift)

### Resumen
La app implementa un planificador de rutas completo usando Dijkstra sobre un grafo de transporte público. El código está en `WatchTrans iOS/Services/RoutingService.swift` (~530 líneas).

### Paso 1: Construcción del Grafo (`buildGraph()`)

```swift
// Configuración
let transferPenaltyMinutes: Double = 3.0  // Penalización por transbordo
let walkingSpeedKmH: Double = 4.5         // Velocidad andando
let averageTrainSpeedKmH: Double = 30.0   // Velocidad media metro/tren

// Estructura del grafo
struct TransitNode: Hashable {
    let stopId: String    // ID de la parada
    let lineId: String?   // ID de la línea (nil para nodos de transbordo)
}

struct TransitEdge {
    let from: TransitNode
    let to: TransitNode
    let weight: Double        // Tiempo en minutos
    let type: EdgeType        // .ride, .transfer, .boarding, .alighting
    let lineId: String?
    let lineName: String?
    let lineColor: String?
}
```

**Proceso de construcción:**
1. Para cada línea en `dataService.lines`:
   - Obtener paradas: `fetchStopsForRoute(routeId)`
   - Crear nodo por cada parada+línea: `TransitNode(stopId, lineId)`
   - Crear aristas bidireccionales entre paradas consecutivas
   - Peso = distancia / velocidad_media * 60 (mínimo 1 minuto)

2. Añadir aristas de transbordo:
   - Agrupar nodos por `stopId`
   - Si hay múltiples líneas en la misma parada → transbordo directo (3 min)
   - Cargar correspondencias de API: `fetchCorrespondences(stopId)`
   - Crear aristas de transbordo andando: peso = tiempo_andando + penalización

### Paso 2: Algoritmo Dijkstra (`dijkstra()`)

```swift
func dijkstra(from start: TransitNode, to goals: Set<TransitNode>) -> ([TransitNode], Double)? {
    var distances: [TransitNode: Double] = [start: 0]
    var previous: [TransitNode: TransitNode] = [:]
    var unvisited = nodes  // Todos los nodos del grafo

    while !unvisited.isEmpty {
        // Encontrar nodo no visitado con menor distancia
        guard let current = unvisited.min(by: {
            (distances[$0] ?? .infinity) < (distances[$1] ?? .infinity)
        }),
        let currentDist = distances[current],
        currentDist < .infinity else {
            break
        }

        // ¿Llegamos al destino?
        if goals.contains(current) {
            // Reconstruir camino
            var path: [TransitNode] = []
            var node: TransitNode? = current
            while let n = node {
                path.insert(n, at: 0)
                node = previous[n]
            }
            return (path, currentDist)
        }

        unvisited.remove(current)

        // Actualizar distancias a vecinos
        for edge in edges[current] ?? [] {
            let alt = currentDist + edge.weight
            if alt < (distances[edge.to] ?? .infinity) {
                distances[edge.to] = alt
                previous[edge.to] = current
            }
        }
    }
    return nil
}
```

### Paso 3: Construir Segmentos del Viaje (`buildSegments()`)

Una vez tenemos el camino de nodos, construimos los segmentos:

```swift
// Para cada cambio de línea:
1. Cerrar segmento anterior
2. Si hay cambio de parada → añadir segmento WALKING
3. Abrir nuevo segmento con la nueva línea

// Para cada segmento TRANSIT:
- Obtener shape de la línea: fetchRouteShape(routeId)
- Extraer porción entre origen y destino del segmento
- Si hay pocos puntos → interpolar para animación suave
```

### Paso 4: Extracción de Shape (`extractShapeSegment()`)

```swift
func extractShapeSegment(from shape: [Coordinate], origin: Coordinate, destination: Coordinate) -> [Coordinate] {
    // 1. Encontrar punto más cercano al origen
    var originIndex = 0
    var minOriginDist = infinity
    for (index, coord) in shape.enumerated() {
        let d = distance(coord, origin)
        if d < minOriginDist {
            minOriginDist = d
            originIndex = index
        }
    }

    // 2. Encontrar punto más cercano al destino
    var destIndex = shape.count - 1
    var minDestDist = infinity
    for (index, coord) in shape.enumerated() {
        let d = distance(coord, destination)
        if d < minDestDist {
            minDestDist = d
            destIndex = index
        }
    }

    // 3. Extraer segmento (respetando dirección)
    if originIndex <= destIndex {
        return shape[originIndex...destIndex]
    } else {
        // Vamos "al revés" en la ruta
        return shape[destIndex...originIndex].reversed()
    }
}
```

### Paso 5: Interpolación de Caminos Andando

```swift
func interpolateWalkingPath(from origin: Stop, to destination: Stop) -> [Coordinate] {
    let start = origin.coordinate
    let end = destination.coordinate

    // Crear 15 puntos interpolados para animación suave
    var result: [Coordinate] = []
    for i in 0..<15 {
        let t = Double(i) / 14.0
        let lat = start.lat + (end.lat - start.lat) * t
        let lon = start.lon + (end.lon - start.lon) * t
        result.append(Coordinate(lat, lon))
    }
    return result
}
```

---

## 0.5 BÚSQUEDA DE PARADAS POR NOMBRE (DataService.swift)

### Lógica Actual

```swift
func searchStops(query: String) async -> [Stop] {
    // 1. Llamar a la API con el query
    let stopResponses = try await gtfsRealtimeService.fetchStops(search: query, limit: 100)

    // 2. Convertir respuestas a modelo Stop
    let allStops = stopResponses.map { response in
        Stop(
            id: response.id,
            name: response.name,
            latitude: response.lat,
            longitude: response.lon,
            // ... más campos
        )
    }

    // 3. FILTRAR por provincia/región actual del usuario
    guard let province = currentLocation?.provinceName else {
        return allStops.prefix(50)  // Sin filtro si no hay ubicación
    }

    // 4. Obtener provincias relacionadas (misma red de transporte)
    let relatedProvinces = getRelatedProvinces(for: province)

    // 5. Filtrar paradas que estén en la región
    let filteredStops = allStops.filter { stop in
        guard let stopProvince = stop.province else { return false }
        return relatedProvinces.contains(stopProvince)
    }

    return filteredStops.prefix(50)
}
```

### Regiones de Red de Transporte

La app agrupa provincias por red de transporte para evitar mostrar estaciones lejanas:

```swift
let networkRegions: [[String]] = [
    // Cataluña (Rodalies, FGC, TMB)
    ["Barcelona", "Tarragona", "Lleida", "Girona"],
    // Madrid (Cercanías Madrid, Metro Madrid)
    ["Madrid"],
    // País Vasco (Euskotren, Metro Bilbao)
    ["Vizcaya", "Guipúzcoa", "Álava", "Bizkaia", "Gipuzkoa", "Araba"],
    // Valencia (Metrovalencia, Cercanías Valencia)
    ["Valencia", "Alicante", "Castellón", "Castelló"],
    // Andalucía - Separadas para evitar estaciones lejanas
    ["Sevilla"],
    ["Málaga"],
    ["Cádiz"],
    ["Granada"],
    // Asturias
    ["Asturias"],
    // Galicia
    ["A Coruña", "Pontevedra", "Lugo", "Ourense"],
    // Murcia
    ["Murcia"],
    // Zaragoza
    ["Zaragoza"],
    // Cantabria
    ["Cantabria"],
    // Mallorca
    ["Illes Balears", "Islas Baleares", "Mallorca"],
]
```

### Endpoint Propuesto (si se quiere mover al servidor)

```
GET /api/v1/gtfs/stops/search?q=Sol&province=Madrid&limit=50
```

O mejor, que el servidor haga el filtrado automático:

```
GET /api/v1/gtfs/stops/search?q=Sol&lat=40.41&lon=-3.70&radius_km=100
```

Así el servidor filtra por proximidad y la app no necesita la lógica de regiones.

---

## 1. Normalización de Shapes (LISTO PARA MIGRAR)

### Estado actual en la app
La app tiene una función `normalizeRoute()` en `AnimationController` (`Journey3DAnimationView.swift:745`) que:
- Recibe coordenadas del shape
- Interpola puntos usando SLERP cuando hay gaps > 50m
- Devuelve array densificado para animación suave

### Cambio requerido
```swift
// ANTES (actual)
let shape = await dataService.fetchRouteShape(routeId: routeId)
let normalizedCoords = AnimationController.normalizeRoute(shape, maxSegmentMeters: 50.0)

// DESPUÉS (con nuevo endpoint)
let shape = await dataService.fetchRouteShape(routeId: routeId, maxGap: 50)
// Ya viene normalizado, usar directamente
```

### Archivos a modificar
- `WatchTrans iOS/Shared/Services/DataService.swift` - añadir parámetro `maxGap` a `fetchRouteShape()`
- `WatchTrans iOS/Views/Journey/Journey3DAnimationView.swift` - eliminar `normalizeRoute()` y `sphericalInterpolate()`

---

## 2. Respuestas a Preguntas del Desarrollador API

### 2.1 ¿La app calcula rutas/itinerarios?

**SÍ** - La app tiene un servicio completo de routing en `RoutingService.swift`:

- **Algoritmo**: Dijkstra para pathfinding en grafo de transporte
- **Funcionalidad**:
  - Construye grafo con todas las líneas y paradas
  - Calcula ruta óptima entre origen y destino
  - Detecta transbordos (andando entre estaciones cercanas)
  - Extrae shapes de cada segmento del viaje
  - Estima tiempos de viaje

**Endpoint propuesto**:
```
GET /api/v1/gtfs/route-planner?from=STOP_ID&to=STOP_ID
```

**Response sugerida**:
```json
{
  "journey": {
    "origin": { "id": "METRO_SEV_L1_E21", "name": "Olivar de Quintos", ... },
    "destination": { "id": "RENFE_43004", "name": "Cartuja", ... },
    "total_duration_minutes": 45,
    "total_walking_minutes": 3,
    "transfer_count": 2,
    "segments": [
      {
        "type": "transit",
        "transport_mode": "metro",
        "line_name": "L1",
        "line_color": "#ED1C24",
        "origin": { "id": "...", "name": "Olivar de Quintos" },
        "destination": { "id": "...", "name": "San Bernardo" },
        "intermediate_stops": [...],
        "duration_minutes": 25,
        "coordinates": [...],  // Ya normalizados con max_gap
        "shape_normalized": true
      },
      {
        "type": "walking",
        "transport_mode": "walking",
        "origin": { "id": "...", "name": "San Bernardo" },
        "destination": { "id": "...", "name": "San Bernardo RENFE" },
        "duration_minutes": 3,
        "distance_meters": 200,
        "coordinates": [...]  // Línea recta entre puntos
      },
      ...
    ]
  }
}
```

**Código a eliminar de la app**:
- `RoutingService.swift` completo (~530 líneas)
- Modelos de grafo en `Journey.swift` (TransitNode, TransitEdge, EdgeType)

---

### 2.2 ¿Hay otros cálculos de geometría?

**SÍ**:

| Cálculo | Ubicación | Uso |
|---------|-----------|-----|
| `calculateHeading(from:to:)` | `Journey3DAnimationView.swift:450` | Orientación de cámara en animación 3D |
| `lineDistance()` | `AnimationController` | Distancia total de ruta en km |
| `coordinateAlong()` | `AnimationController` | Posición a X km del inicio |
| `sphericalInterpolate()` | `AnimationController` | SLERP para normalización |
| `distance(from:to:)` | `RoutingService.swift` | Distancia entre coordenadas |

**Nota**: El cálculo de heading para la cámara está **DESACTIVADO** actualmente porque causa un bug en MapKit donde el polyline desaparece al rotar la cámara. Si el servidor va a manejar esto, podría incluir `suggested_camera_heading` por segmento.

---

### 2.3 ¿La app calcula ETAs o tiempos de viaje?

**SÍ**, de forma básica:

```swift
// RoutingService.swift:521
private func estimateDuration(from: Stop, to: Stop, stops: Int) -> Int {
    // Average 2 minutes per stop
    return max(1, stops * 2)
}

private func estimateWalkingTime(from: Stop, to: Stop) -> Int {
    let distance = from.location.distance(from: to.location)
    let timeHours = (distance / 1000.0) / walkingSpeedKmH  // 4.5 km/h
    return max(1, Int(timeHours * 60))
}
```

**Recomendación**: El servidor podría calcular tiempos más precisos usando:
- Velocidades comerciales reales por tipo de transporte
- Tiempos de espera promedio por línea/hora
- Datos históricos de retrasos

---

### 2.4 ¿Se calculan colores de línea o iconos en la app?

**NO** - Los colores vienen de la API en `route_color`. La app solo tiene fallbacks por si falta:

```swift
private let defaultMetroColor = "#ED1C24"
private let defaultCercaniasColor = "#78B4E1"
// etc.
```

Los iconos son de SF Symbols según el tipo de transporte, definidos en `TransportMode.icon`.

---

### 2.5 ¿Hay filtrado o agrupación en cliente?

**SÍ**:

1. **Filtrado por provincia/región** en búsqueda de paradas:
```swift
// DataService.swift
func searchStops(_ query: String) -> [Stop] {
    // Filtra resultados para mostrar solo paradas de la provincia actual
}
```

2. **Agrupación de líneas por tipo** en UI (pero datos vienen separados de API)

3. **Filtrado de correspondencias** por tipo de transporte

---

### 2.6 ¿Caché compleja en la app?

**MODERADA**:

- Cache de salidas/llegadas por parada (5 min TTL)
- Cache de líneas por ID
- Cache de paradas por ID
- Cache de shapes por route_id
- Cache de transport types por network

No es muy compleja, pero podría simplificarse si la API devuelve datos más agregados.

---

### 2.7 ¿Otros algoritmos pesados?

1. **Construcción de grafo de transporte** (`RoutingService.buildGraph()`):
   - Carga todas las líneas y sus paradas
   - Crea nodos y aristas para pathfinding
   - Detecta conexiones entre estaciones cercanas
   - ~200 llamadas a API para correspondencias

2. **Extracción de segmentos de shape** (`RoutingService.extractSegmentCoordinates()`):
   - Dado un shape completo de una línea, extrae solo la porción entre dos paradas
   - Busca puntos más cercanos a origen/destino

3. **Detección de transbordos a pie**:
   - Busca paradas con nombres similares de diferentes redes
   - Usa correspondencias de la API cuando están disponibles

---

## 3. Prioridad de Migración Sugerida

| Prioridad | Funcionalidad | Impacto | Esfuerzo |
|-----------|---------------|---------|----------|
| 🔴 Alta | Route Planner completo | Elimina ~600 líneas de código | Medio-Alto |
| 🟡 Media | Normalización de shapes | Ya implementado en API | Bajo |
| 🟢 Baja | ETAs más precisos | Mejora UX | Bajo |
| 🟢 Baja | Camera hints para animación | Resuelve bug de MapKit | Bajo |

---

## 4. Bug Conocido: Polyline Desaparece con Rotación de Cámara

### Descripción
Cuando la animación 3D rota la cámara (cambia el heading) mientras se mueve por la ruta, MapKit deja de renderizar el polyline. El polyline reaparece al pausar la animación.

### Workaround Actual
La rotación de cámara está desactivada (`heading: 0` fijo).

### Posible Solución desde API
Si el endpoint de route-planner devuelve `suggested_camera_heading` por segmento, la app podría:
1. No calcular heading en tiempo real
2. Usar transiciones más suaves entre headings predefinidos
3. O simplemente mantener heading fijo (actual)

---

## 5. Archivos Relevantes en la App

```
WatchTrans iOS/
├── Services/
│   └── RoutingService.swift        # 530 líneas - TODO: eliminar tras migración
├── Models/
│   └── Journey.swift               # Modelos de viaje y grafo
├── Views/Journey/
│   └── Journey3DAnimationView.swift # AnimationController con normalización
└── Shared/Services/
    └── DataService.swift           # Llamadas a API, añadir maxGap param
```
