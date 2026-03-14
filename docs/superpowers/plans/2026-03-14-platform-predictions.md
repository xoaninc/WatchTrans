# Platform Predictions Fallback — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a departure has no platform info, fill it with a predicted platform (always marked as estimated/orange).

**Architecture:** Add `PlatformPredictionResponse` model, a `fetchPlatformPredictions()` method in `GTFSRealtimeService`, and enrich arrivals without platform in `GTFSRealtimeMapper.mapToArrivals()` using the existing `withPlatform(_:estimated:)` method. The UI already handles `platformEstimated == true` with an orange badge — zero UI changes needed.

**Tech Stack:** SwiftUI, existing `Arrival.withPlatform()`, existing orange badge in `ArrivalRowView`.

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `WatchTrans iOS/Services/GTFSRT/WatchTransModels.swift` | Add `PlatformPredictionResponse` struct |
| Modify | `WatchTrans iOS/Services/GTFSRT/GTFSRealtimeService.swift` | Add `fetchPlatformPredictions()` method |
| Modify | `WatchTrans iOS/Services/GTFSRT/GTFSRealtimeMapper.swift` | Enrich arrivals without platform |
| Modify | `WatchTrans Watch App/Services/GTFSRT/WatchTransModels.swift` | Same model addition |
| Modify | `WatchTrans Watch App/Services/GTFSRT/GTFSRealtimeService.swift` | Same method addition |
| Modify | `WatchTrans Watch App/Services/GTFSRT/GTFSRealtimeMapper.swift` | Same enrichment |

**Not modified:** `Arrival.swift`, `ArrivalRowView.swift`, `StopDetailView.swift` — already handle `platformEstimated`.

---

## Task 1: Add PlatformPredictionResponse model (both targets)

**Files:**
- Modify: `WatchTrans iOS/Services/GTFSRT/WatchTransModels.swift`
- Modify: `WatchTrans Watch App/Services/GTFSRT/WatchTransModels.swift`

- [ ] **Step 1: Add the model struct to iOS WatchTransModels.swift**

Add after the `PlatformsResponse` / `PlatformInfo` section:

```swift
// MARK: - Platform Prediction Response

/// Response from GET /api/gtfs-rt/platforms/predictions
/// Predicted platform based on 30-day historical data
struct PlatformPredictionResponse: Codable {
    let stopId: String
    let routeShortName: String?
    let headsign: String?
    let predictedPlatform: String
    let confidence: Double          // 0.0 - 1.0
    let sampleSize: Int?

    enum CodingKeys: String, CodingKey {
        case stopId = "stop_id"
        case routeShortName = "route_short_name"
        case headsign
        case predictedPlatform = "predicted_platform"
        case confidence
        case sampleSize = "sample_size"
    }
}
```

- [ ] **Step 2: Add the same struct to Watch WatchTransModels.swift**

Identical code.

- [ ] **Step 3: Commit**

```bash
git add "WatchTrans iOS/Services/GTFSRT/WatchTransModels.swift" \
        "WatchTrans Watch App/Services/GTFSRT/WatchTransModels.swift"
git commit -m "feat: add PlatformPredictionResponse model"
```

---

## Task 2: Add fetchPlatformPredictions method (both targets)

**Files:**
- Modify: `WatchTrans iOS/Services/GTFSRT/GTFSRealtimeService.swift`
- Modify: `WatchTrans Watch App/Services/GTFSRT/GTFSRealtimeService.swift`

- [ ] **Step 1: Add method to iOS GTFSRealtimeService**

Add after the existing `fetchPlatforms` method:

```swift
/// Fetch predicted platforms for a stop based on 30-day historical data
/// Only returns predictions with confidence >= minConfidence
func fetchPlatformPredictions(stopId: String, minConfidence: Double = 0.5) async throws -> [PlatformPredictionResponse] {
    guard var components = URLComponents(string: "\(APIConfiguration.gtfsRTBaseURL)/platforms/predictions") else {
        throw NetworkError.badResponse
    }

    components.queryItems = [
        URLQueryItem(name: "stop_id", value: stopId),
        URLQueryItem(name: "min_confidence", value: String(minConfidence))
    ]

    guard let url = components.url else {
        throw NetworkError.badResponse
    }

    let predictions: [PlatformPredictionResponse] = try await networkService.fetch(url)
    DebugLog.log("🔮 [RT] Fetched \(predictions.count) platform predictions for \(stopId)")
    return predictions
}
```

- [ ] **Step 2: Add same method to Watch GTFSRealtimeService**

Identical code.

- [ ] **Step 3: Commit**

```bash
git add "WatchTrans iOS/Services/GTFSRT/GTFSRealtimeService.swift" \
        "WatchTrans Watch App/Services/GTFSRT/GTFSRealtimeService.swift"
git commit -m "feat: add fetchPlatformPredictions method"
```

---

## Task 3: Enrich arrivals with predicted platforms (both targets)

**Files:**
- Modify: `WatchTrans iOS/Services/GTFSRT/GTFSRealtimeMapper.swift`
- Modify: `WatchTrans Watch App/Services/GTFSRT/GTFSRealtimeMapper.swift`

- [ ] **Step 1: Add enrichment method to iOS GTFSRealtimeMapper**

The mapper already has a reference to `dataService` which has `gtfsRealtimeService`. Add a new method:

```swift
/// Enrich arrivals that have no platform with predicted platforms
/// Only fills in predictions — never overrides existing platform data
func enrichWithPlatformPredictions(arrivals: [Arrival], stopId: String) async -> [Arrival] {
    // Skip if all arrivals already have platforms
    guard arrivals.contains(where: { $0.platform == nil || $0.platform?.isEmpty == true }) else {
        return arrivals
    }

    // Fetch predictions (fail silently — predictions are optional)
    guard let dataService = dataService,
          let predictions = try? await dataService.gtfsRealtimeService.fetchPlatformPredictions(stopId: stopId) else {
        return arrivals
    }

    guard !predictions.isEmpty else { return arrivals }

    return arrivals.map { arrival in
        // Skip if arrival already has a platform
        guard arrival.platform == nil || arrival.platform?.isEmpty == true else {
            return arrival
        }

        // Find matching prediction by line name + destination
        let match = predictions.first { prediction in
            let lineMatch = prediction.routeShortName?.lowercased() == arrival.lineName.lowercased()
            let headsignMatch = prediction.headsign == nil ||
                arrival.destination.lowercased().contains(prediction.headsign?.lowercased() ?? "")
            return lineMatch && headsignMatch
        }

        guard let match = match else { return arrival }

        return arrival.withPlatform(match.predictedPlatform, estimated: true)
    }
}
```

- [ ] **Step 2: Integrate into the data loading flow**

Find where `mapToArrivals` is called in `DataService.swift` (iOS). It's in `fetchArrivalsForStop()`. After the line that calls `mapper.mapToArrivals(departures:stopId:)`, add the enrichment:

```swift
// Before (existing):
let arrivals = mapper.mapToArrivals(departures: departures, stopId: stopId)

// After (add enrichment):
let arrivals = mapper.mapToArrivals(departures: departures, stopId: stopId)
let enrichedArrivals = await mapper.enrichWithPlatformPredictions(arrivals: arrivals, stopId: stopId)
// Use enrichedArrivals instead of arrivals from here on
```

Find the exact location by searching for `mapToArrivals` in DataService.swift and update the variable used downstream.

- [ ] **Step 3: Same changes for Watch target**

Apply identical changes to:
- `WatchTrans Watch App/Services/GTFSRT/GTFSRealtimeMapper.swift`
- `WatchTrans Watch App/Services/DataService.swift`

- [ ] **Step 4: Commit**

```bash
git add "WatchTrans iOS/Services/GTFSRT/GTFSRealtimeMapper.swift" \
        "WatchTrans iOS/Services/DataService.swift" \
        "WatchTrans Watch App/Services/GTFSRT/GTFSRealtimeMapper.swift" \
        "WatchTrans Watch App/Services/DataService.swift"
git commit -m "feat: enrich arrivals without platform using historical predictions"
```

---

## Verification

After implementation, test with a real stop that has departures without platform info:

```bash
# Check if predictions exist for a stop
curl -s "https://api.watch-trans.app/api/gtfs-rt/platforms/predictions?stop_id=RENFE_C_10202&min_confidence=0.5"

# Check departures to see which have platform=null
curl -s "https://api.watch-trans.app/api/gtfs/stops/RENFE_C_10202/departures?limit=5"
```

Expected behavior:
- Departures with `platform` from operator → shown in blue badge (unchanged)
- Departures with `platform: null` + prediction match → shown in orange badge with predicted platform
- Departures with `platform: null` + no prediction → no badge (unchanged)
