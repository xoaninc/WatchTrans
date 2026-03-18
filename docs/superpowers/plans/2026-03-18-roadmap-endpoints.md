# Roadmap Endpoints — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate 4 remaining roadmap endpoints: tarifas, trip-updates, vehicle occupancy, and route service status.

**Architecture:** Each endpoint gets: model in WatchTransModels, fetch in GTFSRealtimeService/DataService, UI in existing views. All new fields use `var` with defaults or optionals to avoid breaking existing callsites.

**Tech Stack:** Swift, SwiftUI, Codable

**Spec:** `docs/superpowers/specs/2026-03-18-roadmap-endpoints-design.md`

---

## Task 1: Tarifas — model + fetch + UI

**Files:**
- Modify: `WatchTrans iOS/Services/GTFSRT/WatchTransModels.swift` (add models)
- Modify: `WatchTrans iOS/Services/GTFSRT/GTFSRealtimeService.swift` (add fetch)
- Modify: `WatchTrans iOS/Views/Lines/LineDetailView.swift` (add section + fetch call)

- [ ] **Step 1: Add RouteFaresResponse and FareEntry to WatchTransModels.swift**

```swift
// MARK: - Route Fares Response

struct RouteFaresResponse: Codable {
    let routeId: String
    let currency: String
    let paymentMethod: Int?
    let transfersAllowed: Int?
    let fares: [FareEntry]

    enum CodingKeys: String, CodingKey {
        case routeId = "route_id"
        case currency
        case paymentMethod = "payment_method"
        case transfersAllowed = "transfers_allowed"
        case fares
    }
}

struct FareEntry: Codable, Identifiable {
    let price: Double
    let originZone: String
    let destinationZone: String

    var id: String { "\(originZone)-\(destinationZone)-\(price)" }

    enum CodingKeys: String, CodingKey {
        case price
        case originZone = "origin_zone"
        case destinationZone = "destination_zone"
    }
}
```

- [ ] **Step 2: Add fetchFares to GTFSRealtimeService**

```swift
func fetchFares(routeId: String) async throws -> RouteFaresResponse {
    guard let encodedId = routeId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
          let url = URL(string: "\(baseURL)/routes/\(encodedId)/fares") else {
        throw NetworkError.badResponse
    }
    return try await networkService.fetch(url)
}
```

- [ ] **Step 3: Add fares section to LineDetailView**

Add `@State private var fares: [FareEntry] = []` to LineDetailView.

In `loadData()`, after operating hours fetch:
```swift
if let routeId = line.routeIds.first {
    if let faresResponse = try? await dataService.gtfsRealtimeService.fetchFares(routeId: routeId), !faresResponse.fares.isEmpty {
        fares = faresResponse.fares
    }
}
```

Add section in body after operating hours, before route map:
```swift
if !fares.isEmpty {
    VStack(alignment: .leading, spacing: 6) {
        HStack {
            Image(systemName: "eurosign.circle")
                .foregroundStyle(.green)
            Text("Tarifas")
                .font(.headline)
        }
        ForEach(fares.prefix(10)) { fare in
            HStack {
                Text("\(fare.originZone) → \(fare.destinationZone)")
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.2f €", fare.price))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
        if fares.count > 10 {
            Text("\(fares.count - 10) tarifas mas...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    .padding()
    .background(Color(.systemGray6))
    .cornerRadius(10)
}
```

- [ ] **Step 4: Build, commit and push**

---

## Task 2: Trip updates — wire existing dead code to TrainDetailView

**Files:**
- Modify: `WatchTrans iOS/Services/GTFSRT/WatchTransModels.swift` (add TripUpdateResponse if not exists)
- Modify: `WatchTrans iOS/Views/Stop/TrainDetailView.swift` (fetch and display)

- [ ] **Step 1: Add TripUpdateResponse model if missing**

Check if model exists. The fetch `fetchTripUpdates` already exists in GTFSRealtimeService but returns raw `Data`. Need a proper Codable model:

```swift
struct TripUpdateResponse: Codable, Identifiable {
    let id: String
    let operatorId: String
    let tripId: String
    let routeId: String
    let delay: Int
    let vehicleId: String?
    let timestamp: String

    enum CodingKeys: String, CodingKey {
        case id, delay, timestamp
        case operatorId = "operator_id"
        case tripId = "trip_id"
        case routeId = "route_id"
        case vehicleId = "vehicle_id"
    }
}
```

- [ ] **Step 2: Add typed fetch to GTFSRealtimeService**

The existing `fetchTripUpdates` returns `Data`. Add a typed version:

```swift
func fetchTripUpdateForTrip(tripId: String) async throws -> TripUpdateResponse? {
    guard var components = URLComponents(string: "\(APIConfiguration.gtfsRTBaseURL)/trip-updates") else {
        throw NetworkError.badResponse
    }
    components.queryItems = [
        URLQueryItem(name: "limit", value: "50")
    ]
    guard let url = components.url else { throw NetworkError.badResponse }
    let updates: [TripUpdateResponse] = try await networkService.fetch(url)
    return updates.first { $0.tripId == tripId }
}
```

- [ ] **Step 3: In TrainDetailView, fetch and show precise delay**

Add `@State private var tripUpdate: TripUpdateResponse? = nil`.

In loadTripDetails (or wherever trip data loads), add:
```swift
tripUpdate = try? await dataService.gtfsRealtimeService.fetchTripUpdateForTrip(tripId: arrival.id)
```

In the delay display section, if tripUpdate exists, show seconds precision:
```swift
if let update = tripUpdate {
    let minutes = update.delay / 60
    let seconds = update.delay % 60
    Text("Retraso: \(minutes) min \(seconds) seg")
        .font(.caption)
        .foregroundStyle(.orange)
}
```

- [ ] **Step 4: Build, commit and push**

---

## Task 3: Vehicle occupancy — FGC departures

**Files:**
- Modify: `WatchTrans iOS/Services/GTFSRT/WatchTransModels.swift` (add model)
- Modify: `WatchTrans iOS/Services/GTFSRT/GTFSRealtimeService.swift` (add typed fetch)
- Modify: `WatchTrans iOS/Views/Stop/StopDetailView.swift` (fetch for FGC)
- Modify: `WatchTrans iOS/Components/ArrivalRowView.swift` (show badge)
- Modify: `WatchTrans iOS/Models/Arrival.swift` (add vehicleOccupancy field)
- Modify: `WatchTrans iOS/Services/GTFSRT/GTFSRealtimeMapper.swift` (no change needed — occupancy comes separately)

- [ ] **Step 1: Add VehicleOccupancyResponse model**

```swift
struct VehicleOccupancyResponse: Codable, Identifiable {
    let vehicleId: String
    let operatorId: String
    let tripId: String?
    let routeId: String?
    let routeShortName: String?
    let headsign: String?
    let occupancyStatus: Int
    let occupancyStatusLabel: String?
    let occupancyPercentage: Int?
    let latitude: Double?
    let longitude: Double?
    let currentStopId: String?
    let timestamp: String

    var id: String { vehicleId }

    enum CodingKeys: String, CodingKey {
        case vehicleId = "vehicle_id"
        case operatorId = "operator_id"
        case tripId = "trip_id"
        case routeId = "route_id"
        case routeShortName = "route_short_name"
        case headsign
        case occupancyStatus = "occupancy_status"
        case occupancyStatusLabel = "occupancy_status_label"
        case occupancyPercentage = "occupancy_percentage"
        case latitude, longitude, timestamp
        case currentStopId = "current_stop_id"
    }
}
```

- [ ] **Step 2: Add typed fetch to GTFSRealtimeService**

```swift
func fetchVehicleOccupancy(operatorId: String) async throws -> [VehicleOccupancyResponse] {
    guard var components = URLComponents(string: "\(APIConfiguration.gtfsRTBaseURL)/occupancy") else {
        throw NetworkError.badResponse
    }
    components.queryItems = [
        URLQueryItem(name: "operator_id", value: operatorId)
    ]
    guard let url = components.url else { throw NetworkError.badResponse }
    return try await networkService.fetch(url)
}
```

- [ ] **Step 3: Fetch in StopDetailView for FGC stops and pass to DeparturesSectionView**

In `StopDetailView`, add `@State private var vehicleOccupancy: [String: Int] = [:]` (tripId → occupancyStatus).

In `loadData()`, for FGC stops:
```swift
if stop.id.hasPrefix("FGC_") {
    let occupancy = (try? await dataService.gtfsRealtimeService.fetchVehicleOccupancy(operatorId: "fgc")) ?? []
    for occ in occupancy {
        if let tripId = occ.tripId {
            vehicleOccupancy[tripId] = occ.occupancyStatus
        }
    }
}
```

Pass `vehicleOccupancy` to `DeparturesSectionView` and then to each `ArrivalRowView`.

- [ ] **Step 4: Show occupancy badge in ArrivalRowView**

ArrivalRowView already has `OccupancyIndicator`. Add a new optional parameter `vehicleOccupancyStatus: Int? = nil`. When present and valid (not 7/NO_DATA), show the indicator.

- [ ] **Step 5: Build, commit and push**

---

## Task 4: is_alternative_service in LinesListView

**Files:**
- Modify: `WatchTrans iOS/Views/Lines/LinesListView.swift`

The `Line` model already has `isAlternativeService: Bool?`. The data comes from route processing in DataService. Just need to show it in the UI.

- [ ] **Step 1: Add bus label in LinesListView line row**

In the line description VStack (after the suspension label), add:

```swift
if line.isAlternativeService == true {
    HStack(spacing: 4) {
        Image(systemName: "bus.fill")
            .font(.caption2)
        Text("Servicio alternativo")
    }
    .font(.caption)
    .foregroundStyle(.orange)
}
```

- [ ] **Step 2: Build, commit and push**

---

## Task 5: Update ROADMAP — mark all 4 as implemented

- [ ] **Step 1: Mark 3.1, 3.13, 3.14, 3.19 as resolved in ROADMAP.md. Commit and push.**
