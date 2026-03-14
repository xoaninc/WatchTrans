# Metro Sevilla RT Updates — Design Spec

**Date:** 2026-03-14
**Status:** Approved
**Scope:** iOS + watchOS targets

## Context

The backend API for Metro Sevilla (and Zaragoza) pushed several changes today:

1. `train_position` now includes `current_stop_id` and `timestamp`
2. `lineas` field removed from API responses (already gone)
3. Double compositions: headsign contains `/T.DOBLE`, vehicleLabel is comma-separated (e.g., "108,119")
4. Short-turns: headsign can be intermediate station (e.g., "COCHERAS")

The Watch app is currently broken — `connectionLineIds` is always `[]` because it depended on `lineas`.

## Changes

### Layer 1: Models (both targets)

#### 1A. TrainPositionResponse — add new fields

**Files:** `WatchTrans iOS/Services/GTFSRT/WatchTransModels.swift`, `WatchTrans Watch App/Services/GTFSRT/WatchTransModels.swift`

Add two optional fields to `TrainPositionResponse`:

```swift
struct TrainPositionResponse: Codable {
    let latitude: Double
    let longitude: Double
    let currentStopName: String?
    let currentStopId: String?      // NEW
    let status: String?
    let progressPercent: Double?
    let estimated: Bool?
    let timestamp: String?           // NEW — ISO8601
}
```

CodingKeys: add `currentStopId = "current_stop_id"` and `timestamp` explicitly (codebase convention lists all keys).

Propagate to `Arrival` model (both targets): add `trainCurrentStopId: String?` and `trainPositionTimestamp: String?`. Map in `GTFSRealtimeMapper`. Update `Arrival.withPlatform()` in both targets to pass through the new fields. No view changes needed — the UI already shows `currentStopName`.

#### 1B. Watch StopResponse — remove lineas dependency

**File:** `WatchTrans Watch App/Services/GTFSRT/WatchTransModels.swift`

The `lineIds` computed property currently parses `lineas` which no longer exists in the API (always `nil`). Replace it to build connection IDs from `cor_*` fields — a new pattern for Watch (iOS derives transport type differently, directly from `cor_*` fields on the Stop model):

```swift
var lineIds: [String] {
    var ids: [String] = []
    ids.append(contentsOf: parseCorField(corMetro))
    ids.append(contentsOf: parseCorField(corMl))
    ids.append(contentsOf: parseCorField(corTren))
    ids.append(contentsOf: parseCorField(corTranvia))
    ids.append(contentsOf: parseCorField(corFunicular))
    return ids
}

private func parseCorField(_ value: String?) -> [String] {
    guard let value = value, !value.isEmpty else { return [] }
    return value.split(separator: ",")
        .map { String($0).trimmingCharacters(in: .whitespaces).lowercased() }
        .filter { !$0.isEmpty }
}
```

Keep `lineas` as an optional field in the struct (decodes as `nil` now, harmless).

#### 1C. Watch DataService — no mapping changes needed

**File:** `WatchTrans Watch App/Services/DataService.swift`

The 5 places that map `StopResponse` → `Stop` already pass `corMetro`, `corMl`, `corTren`, `corTranvia`, `corBus`, `corFunicular`, and `correspondences`. The `connectionLineIds: response.lineIds` call will now work correctly because `lineIds` reads from `cor_*` fields instead of `lineas`.

No changes needed in the mapping code — only the `lineIds` implementation changes.

#### 1D. Watch DepartureResponse — add vehicleLabel

**File:** `WatchTrans Watch App/Services/GTFSRT/WatchTransModels.swift`

The Watch `DepartureResponse` is missing `vehicleLabel` (iOS already has it). Add:

```swift
let vehicleLabel: String?       // Train unit identifier (e.g., "MS-07", or "108,119" for double)
```

CodingKey: `vehicleLabel = "vehicle_label"`.

Also add `vehicleLabel: String?` to the Watch `Arrival` model and map it in Watch `GTFSRealtimeMapper`. Update Watch `Arrival.withPlatform()` to pass it through.

### Layer 2: Views (both targets)

#### 2A. T.DOBLE — clean headsign + badge

**Variable flow in GTFSRealtimeMapper** (replaces current headsign → destination logic):

```swift
// 1. Extract raw headsign
let rawHeadsign = departure.headsign ?? ""

// 2. Detect double composition
let isDoubleComposition = departure.vehicleLabel?.contains(",") == true
    || rawHeadsign.uppercased().contains("/T.DOBLE")

// 3. Clean headsign (strip /T.DOBLE suffix)
let cleanHeadsign = rawHeadsign
    .replacingOccurrences(of: "/T.DOBLE", with: "", options: .caseInsensitive)
    .replacingOccurrences(of: "/T. DOBLE", with: "", options: .caseInsensitive)
    .trimmingCharacters(in: .whitespaces)

// 4. Terminus check uses cleaned headsign
if !cleanHeadsign.isEmpty,
   let stopName = currentStopName,
   cleanHeadsign.localizedCaseInsensitiveCompare(stopName) == .orderedSame {
    continue // skip terminus
}

// 5. Use cleaned headsign as destination
let destination = cleanHeadsign.isEmpty ? "Unknown" : cleanHeadsign
```

This replaces the current `if let headsign = departure.headsign` terminus check and `let destination = departure.headsign ?? "Unknown"` assignment.

**Badge:** Add `isDoubleComposition: Bool` (default `false`) to the `Arrival` model in both targets. Update `Arrival.withPlatform()` in both targets. In `ArrivalRowView` (iOS) and `ArrivalCard` (Watch), show a small badge when true.

#### 2B. Short-turns

No additional handling needed beyond the headsign cleanup above. The app already displays headsign as-is for the destination, which correctly shows intermediate stations like "COCHERAS".

## Files Changed

| File | Change |
|------|--------|
| `WatchTransModels.swift` (both) | Add `currentStopId`, `timestamp` to TrainPositionResponse |
| `WatchTransModels.swift` (Watch) | Replace `lineIds` to use `cor_*` instead of `lineas`; add `vehicleLabel` to DepartureResponse |
| `Arrival.swift` (both) | Add `trainCurrentStopId`, `trainPositionTimestamp`, `isDoubleComposition`; update `withPlatform()` |
| `Arrival.swift` (Watch) | Also add `vehicleLabel` |
| `GTFSRealtimeMapper.swift` (both) | Clean `/T.DOBLE` from headsign before terminus check, set `isDoubleComposition`, map new train_position fields |
| `ArrivalRowView.swift` (iOS) | Show double composition badge |
| `ArrivalCard.swift` (Watch) | Show double composition badge |

## What This Does NOT Change

- No new API calls
- No view layout restructuring
- No changes to alert logic (already fixed today)
- `lineas` field kept in Watch StopResponse as optional nil (harmless)
- `StopFullDetailResponse.lineas` (Watch) also decodes as nil — no action needed
- `train_position` UI unchanged (already shows currentStopName)

## Testing

- Build both targets
- Verify Watch `lineIds` returns correct values from `cor_*` fields
- Verify `/T.DOBLE` stripped from headsign display
- Verify terminus filter works with cleaned headsign
- Verify `isDoubleComposition` badge appears for comma-separated vehicleLabel
- Verify `Arrival.withPlatform()` preserves all new fields
