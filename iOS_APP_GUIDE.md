# WatchTrans iOS App - Guía de Desarrollo

Este documento describe cómo crear la app de iOS basándose en la arquitectura existente de watchOS, junto con sugerencias de nuevas funcionalidades.

---

## 1. Arquitectura Actual (watchOS)

### Estructura de Carpetas
```
WatchTrans Watch App/
├── Models/
│   ├── Arrival.swift          # Modelo de llegada/salida
│   ├── Line.swift             # Modelo de línea
│   ├── Stop.swift             # Modelo de parada
│   ├── TransportType.swift    # Enum de tipos de transporte
│   └── Favorite.swift         # SwiftData model para favoritos
├── Views/
│   ├── ContentView.swift      # Pantalla principal
│   ├── StopDetailView.swift   # Detalle de parada
│   ├── LineDetailView.swift   # Detalle de línea
│   ├── LinesView.swift        # Browser de líneas
│   ├── ArrivalCard.swift      # Componente de llegada
│   └── TrainDetailView.swift  # Detalle de tren
├── Services/
│   ├── DataService.swift      # Orquestador de datos
│   ├── LocationService.swift  # CoreLocation
│   ├── FavoritesManager.swift # Gestión de favoritos (SwiftData)
│   ├── NetworkService.swift   # Cliente HTTP con retry
│   ├── NetworkMonitor.swift   # Monitorización de conexión
│   ├── APIConfiguration.swift # Configuración centralizada
│   └── GTFSRT/
│       ├── GTFSRealtimeService.swift  # Cliente API
│       ├── GTFSRealtimeMapper.swift   # Mapper API → Modelos
│       └── RenfeServerModels.swift    # DTOs de la API
└── Extensions/
    └── Color+Hex.swift        # Parse hex colors
```

### Código 100% Reutilizable en iOS

| Archivo | Reutilizable | Notas |
|---------|--------------|-------|
| `Models/*` | ✅ 100% | Sin cambios |
| `Services/DataService.swift` | ✅ 100% | Sin cambios |
| `Services/LocationService.swift` | ✅ 100% | Sin cambios |
| `Services/FavoritesManager.swift` | ✅ 100% | Sin cambios |
| `Services/NetworkService.swift` | ✅ 100% | Sin cambios |
| `Services/NetworkMonitor.swift` | ✅ 100% | Sin cambios |
| `Services/APIConfiguration.swift` | ✅ 100% | Sin cambios |
| `Services/GTFSRT/*` | ✅ 100% | Sin cambios |
| `Extensions/*` | ✅ 100% | Sin cambios |
| `Views/*` | ❌ 0% | Rediseñar para iOS |

**Resumen**: ~80% del código se puede compartir. Solo las vistas necesitan rediseño.

---

## 2. Estructura Propuesta para iOS

```
WatchTrans/
├── Shared/                    # Código compartido (watchOS + iOS)
│   ├── Models/
│   ├── Services/
│   └── Extensions/
├── WatchTrans Watch App/      # Target watchOS (actual)
│   └── Views/
├── WatchTrans iOS/            # Target iOS (nuevo)
│   ├── Views/
│   │   ├── MainTabView.swift
│   │   ├── Home/
│   │   │   ├── HomeView.swift
│   │   │   ├── NearbyStopsSection.swift
│   │   │   └── FavoritesSection.swift
│   │   ├── Search/
│   │   │   ├── SearchView.swift
│   │   │   └── SearchResultRow.swift
│   │   ├── Lines/
│   │   │   ├── LinesListView.swift
│   │   │   ├── LineDetailView.swift
│   │   │   └── LineStopsMapView.swift
│   │   ├── Stop/
│   │   │   ├── StopDetailView.swift
│   │   │   ├── DeparturesListView.swift
│   │   │   └── StopMapView.swift
│   │   ├── Map/
│   │   │   ├── FullMapView.swift
│   │   │   ├── TrainAnnotation.swift
│   │   │   └── StopAnnotation.swift
│   │   ├── Alerts/
│   │   │   ├── AlertsListView.swift
│   │   │   └── AlertDetailView.swift
│   │   └── Settings/
│   │       └── SettingsView.swift
│   └── Components/
│       ├── LineBadge.swift
│       ├── ArrivalRow.swift
│       ├── DelayIndicator.swift
│       └── PlatformBadge.swift
└── WatchTransWidget/          # Widget (actual)
```

---

## 3. Diseño de UI para iOS

### 3.1 Tab Bar Principal

```
┌─────────────────────────────────────┐
│  [Inicio]  [Buscar]  [Mapa]  [Más]  │
└─────────────────────────────────────┘
```

| Tab | Icono | Función |
|-----|-------|---------|
| Inicio | `house.fill` | Favoritos + Cercanas |
| Buscar | `magnifyingglass` | Búsqueda de paradas |
| Mapa | `map.fill` | Mapa con trenes en tiempo real |
| Más | `ellipsis` | Líneas, Alertas, Ajustes |

### 3.2 Pantalla de Inicio (HomeView)

```
┌─────────────────────────────────────┐
│ 📍 Madrid                      [⚙️] │
├─────────────────────────────────────┤
│                                     │
│ ⭐ FAVORITOS                        │
│ ┌─────────────────────────────────┐ │
│ │ 🚉 Sol                     →    │ │
│ │    C3 Aranjuez        3 min     │ │
│ │    C4 Parla           5 min     │ │
│ └─────────────────────────────────┘ │
│ ┌─────────────────────────────────┐ │
│ │ 🚉 Atocha                  →    │ │
│ │    C1 P.Pío           2 min     │ │
│ └─────────────────────────────────┘ │
│                                     │
│ 📍 CERCANAS                         │
│ ┌─────────────────────────────────┐ │
│ │ 🚉 Embajadores (450m)      →    │ │
│ │    C5 Móstoles        4 min     │ │
│ └─────────────────────────────────┘ │
│                                     │
└─────────────────────────────────────┘
```

### 3.3 Pantalla de Búsqueda (SearchView)

```
┌─────────────────────────────────────┐
│ 🔍 Buscar parada...                 │
├─────────────────────────────────────┤
│                                     │
│ RECIENTES                           │
│ ┌─────────────────────────────────┐ │
│ │ 🕐 Sol                          │ │
│ │ 🕐 Atocha                       │ │
│ └─────────────────────────────────┘ │
│                                     │
│ RESULTADOS                          │
│ ┌─────────────────────────────────┐ │
│ │ 🚉 Sol                          │ │
│ │    C1, C2, C3, C4 | L1, L2, L3  │ │
│ ├─────────────────────────────────┤ │
│ │ 🚉 Puerta del Sol               │ │
│ │    L1, L2, L3                   │ │
│ └─────────────────────────────────┘ │
│                                     │
└─────────────────────────────────────┘
```

### 3.4 Pantalla de Mapa (FullMapView)

```
┌─────────────────────────────────────┐
│ [Filtros: C3 ✓ L1 ✓ ...]    [📍]   │
├─────────────────────────────────────┤
│                                     │
│     🚉────🚃────🚉────🚉────🚉     │
│      │                    │         │
│      │    ┌───────┐      │         │
│     🚃    │ 🚃 C3 │     🚉         │
│      │    │Aranjuez│      │         │
│      │    │+2 min │      │         │
│     🚉    └───────┘     🚃         │
│      │                    │         │
│     🚉────────────────🚉           │
│                                     │
├─────────────────────────────────────┤
│ 🚃 C3 Aranjuez - En Sol (+2 min)   │
│ 🚃 C4 Parla - En Atocha            │
└─────────────────────────────────────┘
```

### 3.5 Detalle de Parada (StopDetailView)

```
┌─────────────────────────────────────┐
│ ←  Sol                        [⭐]  │
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │        [Mapa pequeño]           │ │
│ │   🚉 Sol                        │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ⚠️ Alerta: Retrasos en C3 por...   │
│                                     │
│ PRÓXIMAS SALIDAS                    │
│ ┌─────────────────────────────────┐ │
│ │ C3  Aranjuez              3 min │ │
│ │     Vía 4 · En camino a Sol     │ │
│ │     ████████░░░░░░░░  +2 min    │ │
│ ├─────────────────────────────────┤ │
│ │ C4  Parla                 5 min │ │
│ │     Vía 6                       │ │
│ │     ██████░░░░░░░░░░░░          │ │
│ ├─────────────────────────────────┤ │
│ │ C3  Chamartín            8 min  │ │
│ │     Vía 3                       │ │
│ └─────────────────────────────────┘ │
│                                     │
│ CORRESPONDENCIAS                    │
│ [L1] [L2] [L3] [C1] [C2] [C4]      │
│                                     │
└─────────────────────────────────────┘
```

---

## 4. Nuevas Funcionalidades Sugeridas

### 4.1 Búsqueda de Paradas ⭐ (Prioridad Alta)

**Ya implementado en backend**: `GET /stops?search=sol`

**Código a añadir** (ya existe `searchStops()` en DataService):

```swift
// SearchView.swift
struct SearchView: View {
    @State private var query = ""
    @State private var results: [Stop] = []
    let dataService: DataService

    var body: some View {
        VStack {
            TextField("Buscar parada...", text: $query)
                .textFieldStyle(.roundedBorder)
                .onChange(of: query) { _, newValue in
                    Task {
                        if newValue.count >= 2 {
                            results = await dataService.searchStops(query: newValue)
                        }
                    }
                }

            List(results) { stop in
                NavigationLink(destination: StopDetailView(stop: stop)) {
                    StopSearchRow(stop: stop)
                }
            }
        }
    }
}
```

---

### 4.2 Mapa con Trenes en Tiempo Real ⭐ (Prioridad Alta)

**Ya implementado en backend**: `GET /realtime/estimated`, `GET /realtime/networks/{id}/estimated`

**Código a añadir**:

```swift
// FullMapView.swift
import MapKit

struct FullMapView: View {
    @State private var trainPositions: [EstimatedPositionResponse] = []
    @State private var region = MKCoordinateRegion(...)
    let dataService: DataService

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: trainPositions) { train in
            MapAnnotation(coordinate: CLLocationCoordinate2D(
                latitude: train.position.latitude,
                longitude: train.position.longitude
            )) {
                TrainAnnotationView(train: train)
            }
        }
        .task {
            await loadTrainPositions()
        }
    }

    func loadTrainPositions() async {
        // Usar el endpoint de posiciones estimadas
        if let location = dataService.currentLocation {
            for network in location.networks {
                do {
                    let positions = try await gtfsRealtimeService
                        .fetchEstimatedPositionsForNetwork(networkId: network.code)
                    trainPositions.append(contentsOf: positions)
                } catch {
                    print("Error: \(error)")
                }
            }
        }
    }
}
```

---

### 4.3 Ver Recorrido Completo del Tren ⭐ (Prioridad Media)

**Ya implementado en backend**: `GET /trips/{trip_id}`

**Código a añadir**:

```swift
// TripDetailView.swift (iOS version)
struct TripDetailView: View {
    let arrival: Arrival
    @State private var tripStops: [TripStopResponse] = []
    @State private var currentStopIndex: Int?
    let dataService: DataService

    var body: some View {
        List {
            ForEach(Array(tripStops.enumerated()), id: \.element.stopId) { index, stop in
                HStack {
                    // Indicador de progreso vertical
                    VStack {
                        Circle()
                            .fill(index <= (currentStopIndex ?? 0) ? Color.green : Color.gray)
                            .frame(width: 12, height: 12)
                        if index < tripStops.count - 1 {
                            Rectangle()
                                .fill(index < (currentStopIndex ?? 0) ? Color.green : Color.gray)
                                .frame(width: 2, height: 30)
                        }
                    }

                    VStack(alignment: .leading) {
                        Text(stop.stopName)
                            .fontWeight(index == currentStopIndex ? .bold : .regular)
                        Text(formatTime(stop.arrivalTime))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if index == currentStopIndex {
                        Text("🚃")
                    }
                }
            }
        }
        .task {
            if let trip = await dataService.fetchTripDetails(tripId: arrival.id) {
                tripStops = trip.stops
                // Encontrar parada actual
                currentStopIndex = tripStops.firstIndex { $0.stopName == arrival.trainCurrentStop }
            }
        }
        .navigationTitle("\(arrival.lineName) → \(arrival.destination)")
    }
}
```

---

### 4.4 Deep Links ⭐ (Prioridad Media)

**Endpoint necesario**: `GET /stops/{stop_id}` (ya existe en API)

**Código a añadir en GTFSRealtimeService**:

```swift
/// Fetch a specific stop by ID
func fetchStop(stopId: String) async throws -> StopResponse {
    guard let url = URL(string: "\(baseURL)/stops/\(stopId)") else {
        throw NetworkError.badResponse
    }
    return try await networkService.fetch(url)
}
```

**Configurar URL Scheme**:

```xml
<!-- Info.plist -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>watchtrans</string>
        </array>
    </dict>
</array>
```

**Manejar deep links**:

```swift
// WatchTransApp.swift (iOS)
@main
struct WatchTransApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // watchtrans://stop/RENFE_18000
                    if url.host == "stop", let stopId = url.pathComponents.last {
                        // Navegar a la parada
                        navigateToStop(stopId: stopId)
                    }
                }
        }
    }
}
```

---

### 4.5 Notificaciones de Retrasos ⭐ (Prioridad Media)

**Funcionalidad**: Alertar cuando un tren favorito tenga retraso significativo.

```swift
// NotificationService.swift
import UserNotifications

class NotificationService {
    static let shared = NotificationService()

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func scheduleDelayNotification(for arrival: Arrival) {
        guard arrival.isDelayed && arrival.delayMinutes >= 5 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Retraso en \(arrival.lineName)"
        content.body = "El tren a \(arrival.destination) tiene +\(arrival.delayMinutes) min de retraso"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: arrival.id,
            content: content,
            trigger: nil  // Inmediato
        )

        UNUserNotificationCenter.current().add(request)
    }
}
```

---

### 4.6 Planificador de Rutas (Prioridad Baja - Futuro)

**Requiere**: Implementar algoritmo de routing (Dijkstra/A*) en el servidor o usar API externa.

**Concepto**:
```
┌─────────────────────────────────────┐
│ PLANIFICAR RUTA                     │
├─────────────────────────────────────┤
│ Desde: [Sol                    🔍]  │
│ Hasta: [Aeropuerto T4          🔍]  │
│ Salir:  [Ahora ▼]                   │
│                                     │
│ [        BUSCAR RUTA        ]       │
├─────────────────────────────────────┤
│ MEJOR RUTA (45 min)                 │
│                                     │
│ 🚉 Sol                              │
│  │ C4 → Chamartín (15 min)          │
│ 🚉 Chamartín                        │
│  │ 🚶 Transbordo (5 min)            │
│ 🚉 Chamartín                        │
│  │ L8 → Aeropuerto T4 (25 min)      │
│ ✈️ Aeropuerto T4                    │
└─────────────────────────────────────┘
```

---

### 4.7 Widget de iOS ⭐ (Prioridad Alta)

**Tipos de widgets**:

| Tamaño | Contenido |
|--------|-----------|
| Small | Próxima salida de parada favorita |
| Medium | 3 próximas salidas de parada favorita |
| Large | Favoritos + próximas salidas |
| Lock Screen | Próxima salida (inline/circular) |

```swift
// WatchTransWidget_iOS.swift
struct MediumStopWidget: View {
    let stop: Stop
    let departures: [Arrival]

    var body: some View {
        VStack(alignment: .leading) {
            Text(stop.name)
                .font(.headline)

            ForEach(departures.prefix(3)) { departure in
                HStack {
                    LineBadge(name: departure.lineName, color: departure.routeColor)
                    Text(departure.destination)
                        .lineLimit(1)
                    Spacer()
                    Text("\(departure.minutesUntilArrival) min")
                        .fontWeight(.bold)
                }
            }
        }
        .padding()
    }
}
```

---

### 4.8 Apple Watch Complication Mejorada (Prioridad Media)

**Mejoras**:
- Mostrar icono de la línea (C3, L1) en vez de solo texto
- Color de fondo según la línea
- Indicador de retraso

---

### 4.9 Siri Shortcuts (Prioridad Baja)

```swift
// SiriIntents.swift
import Intents

class GetNextTrainIntent: INIntent {
    @NSManaged var stopName: String?
}

// Manejar: "Hey Siri, ¿cuándo pasa el próximo tren en Sol?"
```

---

### 4.10 Historial de Viajes (Prioridad Baja)

**Concepto**: Guardar automáticamente los viajes realizados basándose en ubicación.

```swift
// TripHistory.swift
@Model
class TripRecord {
    var date: Date
    var originStopId: String
    var destinationStopId: String
    var lineId: String
    var duration: TimeInterval
}
```

---

## 5. Prioridades de Implementación

### Fase 1: MVP iOS (2-3 semanas)
1. ✅ Reutilizar Services/Models de watchOS
2. 🔲 HomeView con favoritos y cercanas
3. 🔲 StopDetailView con salidas
4. 🔲 Búsqueda de paradas (`searchStops`)
5. 🔲 Tab navigation básica

### Fase 2: Funcionalidades Core (2-3 semanas)
6. 🔲 Mapa con trenes en tiempo real
7. 🔲 Ver recorrido completo del tren
8. 🔲 Alertas de servicio
9. 🔲 Widget iOS (Small/Medium)

### Fase 3: Mejoras (2-3 semanas)
10. 🔲 Deep links
11. 🔲 Notificaciones de retrasos
12. 🔲 Widget Lock Screen
13. 🔲 Historial de búsquedas

### Fase 4: Avanzado (Futuro)
14. 🔲 Planificador de rutas
15. 🔲 Siri Shortcuts
16. 🔲 Historial de viajes
17. 🔲 CarPlay (si aplica)

---

## 6. Consideraciones Técnicas

### 6.1 Compartir Código entre Targets

```swift
// Package.swift o crear un framework interno
// Mover a Shared/:
// - Models/
// - Services/
// - Extensions/
```

### 6.2 Diferencias iOS vs watchOS

| Aspecto | watchOS | iOS |
|---------|---------|-----|
| Tamaño pantalla | ~40mm | ~6" |
| Interacción | Digital Crown, taps | Gestos, teclado |
| Background refresh | 15 min mínimo | Más flexible |
| Límite favoritos | 5 | Puede ser mayor |
| Complejidad UI | Mínima | Completa |

### 6.3 Almacenamiento Compartido

Para sincronizar favoritos entre iOS y watchOS:

```swift
// SharedStorage.swift - Actualizar para usar iCloud
class SharedStorage {
    static let shared = SharedStorage()

    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private let localStore = UserDefaults(suiteName: "group.juan.WatchTrans")

    func saveFavorite(_ stopId: String) {
        // Guardar en iCloud para sincronizar
        var favorites = ubiquitousStore.array(forKey: "favorites") as? [String] ?? []
        favorites.append(stopId)
        ubiquitousStore.set(favorites, forKey: "favorites")
        ubiquitousStore.synchronize()
    }
}
```

---

## 7. APIs Disponibles (No usadas actualmente)

| Endpoint | Descripción | Uso sugerido |
|----------|-------------|--------------|
| `GET /stops/{id}` | Detalle de parada | Deep links |
| `GET /trips/{id}` | Recorrido completo | Ver todas las paradas del tren |
| `GET /realtime/estimated` | Posiciones de trenes | Mapa en tiempo real |
| `POST /realtime/fetch` | Forzar actualización | Debug/Admin |

---

## 8. Detección de Servicios Suspendidos (Nuevo)

### 8.1 API Response

El endpoint `/api/v1/gtfs/routes/{route_id}/operating-hours` ahora incluye campos de suspensión:

```json
// Servicio SUSPENDIDO (ej: C9)
{
  "route_id": "RENFE_C9_41",
  "route_short_name": "C9",
  "weekday": null,
  "friday": null,
  "saturday": null,
  "sunday": null,
  "is_suspended": true,
  "suspension_message": "#MadC9 Cercanías Madrid informa: por obras..."
}

// Servicio ACTIVO (ej: C5)
{
  "route_id": "RENFE_C5_38",
  "route_short_name": "C5",
  "weekday": { "first_departure": "05:01:00", "last_departure": "24:46:00", "total_trips": 3512 },
  "friday": { ... },
  "saturday": { ... },
  "sunday": { ... },
  "is_suspended": false,
  "suspension_message": null
}
```

### 8.2 Modelo Swift

```swift
// RenfeServerModels.swift
struct RouteOperatingHoursResponse: Codable {
    let routeId: String
    let routeShortName: String
    let weekday: DayOperatingHours?
    let friday: DayOperatingHours?
    let saturday: DayOperatingHours?
    let sunday: DayOperatingHours?
    let isSuspended: Bool?          // NUEVO
    let suspensionMessage: String?  // NUEVO
}

// DataService.swift
struct OperatingHoursResult {
    let hoursString: String?
    let isSuspended: Bool
    let suspensionMessage: String?

    static func hours(_ hours: String?) -> OperatingHoursResult {
        OperatingHoursResult(hoursString: hours, isSuspended: false, suspensionMessage: nil)
    }

    static func suspended(message: String?) -> OperatingHoursResult {
        OperatingHoursResult(hoursString: nil, isSuspended: true, suspensionMessage: message)
    }
}
```

### 8.3 Uso en la Vista

```swift
// LineDetailView.swift
@State private var operatingHoursResult: OperatingHoursResult?

// En el body:
if let result = operatingHoursResult {
    if result.isSuspended {
        // Banner rojo de servicio suspendido
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "exclamationmark.octagon.fill")
                    .foregroundStyle(.red)
                Text("Servicio suspendido")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            if let message = result.suspensionMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(10)
    } else if let hours = result.hoursString {
        // Horario normal
        HStack {
            Image(systemName: "clock")
                .foregroundStyle(.blue)
            Text("Apertura hoy: \(hours)")
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}
```

---

## 9. Recursos

- **API Base URL**: `https://redcercanias.com/api/v1/gtfs`
- **Repositorio API**: `/Users/juanmaciasgomez/Projects/renfeserver`
- **Repositorio App**: `https://github.com/xoaninc/WatchTrans`

---

*Documento creado: Enero 2026*
*Última actualización: 21 Enero 2026 - Añadido soporte para servicios suspendidos*
