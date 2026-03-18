# Roadmap Endpoints — Design Spec

**Date:** 2026-03-18
**Status:** Approved
**Scope:** iOS only

## 3.1 Tarifas

**Endpoint:** `GET /api/gtfs/routes/{route_id}/fares`

**New model:** `RouteFaresResponse`
```swift
struct RouteFaresResponse: Codable {
    let routeId: String
    let currency: String
    let paymentMethod: Int?
    let transfersAllowed: Int?
    let fares: [FareEntry]
}

struct FareEntry: Codable, Identifiable {
    let price: Double
    let originZone: String
    let destinationZone: String
    var id: String { "\(originZone)-\(destinationZone)" }
}
```

**Where:** New section in `LineDetailView`, after operating hours. Only shown when `fares` array is non-empty.

**UI:** Section "Tarifas" with currency label and list of zone pairs with prices. Group by same-zone fares (intra-zone) vs cross-zone.

**Fetch:** New `DataService.fetchFares(routeId:)`. Called in `LineDetailView.loadData`.

**Data availability:** Metro Bilbao (25 fares), Metro Sevilla (54), Metro Granada (1). Euskotren returns empty.

## 3.13 Trip Updates (retrasos)

**Endpoint:** `GET /api/gtfs-rt/trip-updates?operator_id=renfe&route_id=X`

**New model:** `TripUpdateResponse`
```swift
struct TripUpdateResponse: Codable, Identifiable {
    let id: String
    let operatorId: String
    let tripId: String
    let routeId: String
    let delay: Int
    let vehicleId: String?
    let timestamp: String
}
```

**Where:** `TrainDetailView` — when user taps a departure. Show precise delay in seconds if a trip-update exists for this trip_id.

**UI:** In the delay section of TrainDetailView, if trip-update exists, show "Retraso: X min Y seg" instead of just minutes. Show timestamp of last update.

**Fetch:** `GTFSRealtimeService.fetchTripUpdates` already exists (dead code). Wire it into TrainDetailView.loadTripDetails.

**Data availability:** Renfe has real data. Other operators may have data too.

## 3.14 Ocupación de vehículos

**Endpoint:** `GET /api/gtfs-rt/occupancy?operator_id=fgc`

**New model:** `VehicleOccupancyResponse`
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
}
```

**Where:** Badge in `ArrivalRowView` for FGC departures. Same occupancy icon pattern as TMB station occupancy but per-vehicle.

**UI:** Small occupancy indicator (person icon, green/yellow/red) next to the departure time. Reuse existing `OccupancyLevel` enum and `OccupancyIndicator` view.

**Fetch:** New `DataService.fetchVehicleOccupancy(operatorId:)`. Called in `StopDetailView.loadData` for FGC stops. Match by `trip_id` between departures and occupancy responses.

**Data availability:** FGC has data (occupancy_status 3 = STANDING_ROOM_ONLY, 7 = NO_DATA). Renfe returns empty.

## 3.19 Estado de servicio de rutas

**Endpoint:** `GET /api/gtfs/routes/{route_id}` — fields `is_alternative_service`, `service_status`, `suspended_since`

**Where:** `LinesListView` — when a line has `is_alternative_service == true`, show bus icon next to the line name to indicate it's a replacement service.

**Model:** `RouteResponse` already has `isAlternativeService`. The data comes from the route detail endpoint which `fetchRouteDetail` already calls.

**UI:** In `LinesListView` line row, after the existing suspension label, if `is_alternative_service == true`:
```swift
Label("Bus alternativo", systemImage: "bus.fill")
    .font(.caption)
    .foregroundStyle(.orange)
```

**Fetch:** The `is_alternative_service` flag needs to be propagated to the `Line` model. Currently `Line.isAlternativeService` exists but is populated from the route processing. Need to verify it's actually set from the API response.

## Files Changed

| File | Change |
|------|--------|
| `WatchTransModels.swift` (iOS) | Add `RouteFaresResponse`, `FareEntry`, `TripUpdateResponse`, `VehicleOccupancyResponse` |
| `GTFSRealtimeService.swift` (iOS) | Add `fetchFares(routeId:)`, `fetchVehicleOccupancy(operatorId:)` |
| `DataService.swift` (iOS) | Add wrappers for fares and vehicle occupancy |
| `LineDetailView.swift` (iOS) | Add fares section |
| `TrainDetailView.swift` (iOS) | Add precise delay from trip-updates |
| `ArrivalRowView.swift` (iOS) | Add vehicle occupancy badge for FGC |
| `StopDetailView.swift` (iOS) | Fetch vehicle occupancy for FGC stops |
| `LinesListView.swift` (iOS) | Show bus icon for is_alternative_service |
