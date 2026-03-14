# Metro Sevilla RT Updates — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adapt iOS and watchOS targets to Metro Sevilla RT API changes: new train_position fields, lineas removal, T.DOBLE headsign, vehicleLabel for Watch.

**Architecture:** Model-first approach — update Codable structs and Arrival model, then mapper logic, then view badges. Each task builds on previous ones.

**Tech Stack:** Swift, SwiftUI, Codable, Swift Testing

**Spec:** `docs/superpowers/specs/2026-03-14-metro-sevilla-rt-updates-design.md`

**Important:** New Arrival fields use `var` with defaults to avoid breaking existing `Arrival(...)` callsites in offline builders (`DataService.swift`) and `#Preview` blocks (`TrainDetailView.swift`, `ArrivalRowView.swift`, `ArrivalCard.swift`). Only the mapper needs to set them explicitly.

---

## Task 1: Fix Watch lineIds (URGENT — currently broken)

**Files:**
- Modify: `WatchTrans Watch App/Services/GTFSRT/WatchTransModels.swift`

- [ ] **Step 1: Replace lineIds computed property**

In Watch `WatchTransModels.swift`, find the `lineIds` computed property on `StopResponse` (the block starting with `/// Parse lineas string into array of line IDs`). Replace the entire computed property with:

```swift
/// Build connection line IDs from cor_* fields (lineas field removed from API)
var lineIds: [String] {
    var ids: [String] = []
    for field in [corMetro, corMl, corTren, corTranvia, corFunicular] {
        guard let value = field, !value.isEmpty else { continue }
        let parsed = value.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
        ids.append(contentsOf: parsed)
    }
    return ids
}
```

- [ ] **Step 2: Build Watch target**

```bash
xcodebuild -project WatchTrans.xcodeproj -target "WatchTrans Watch App" -destination "generic/platform=watchOS" build 2>&1 | grep "error:" | grep -v "ActivityKit"
```

Expected: No errors.

- [ ] **Step 3: Commit and push**

```bash
git add "WatchTrans Watch App/Services/GTFSRT/WatchTransModels.swift"
git commit -m "fix(watch): Replace lineIds to use cor_* fields instead of removed lineas"
git push
```

---

## Task 2: Add train_position new fields (both targets)

**Files:**
- Modify: `WatchTrans iOS/Services/GTFSRT/WatchTransModels.swift` (TrainPositionResponse)
- Modify: `WatchTrans Watch App/Services/GTFSRT/WatchTransModels.swift` (TrainPositionResponse)
- Modify: `WatchTrans iOS/Models/Arrival.swift` (add fields + withPlatform)
- Modify: `WatchTrans Watch App/Models/Arrival.swift` (add fields + withPlatform)
- Modify: `WatchTrans iOS/Services/GTFSRT/GTFSRealtimeMapper.swift` (map new fields)
- Modify: `WatchTrans Watch App/Services/GTFSRT/GTFSRealtimeMapper.swift` (map new fields)

- [ ] **Step 1: Update TrainPositionResponse in both targets**

In both `WatchTransModels.swift` files, replace the entire `TrainPositionResponse` struct (including CodingKeys):

```swift
struct TrainPositionResponse: Codable {
    let latitude: Double
    let longitude: Double
    let currentStopName: String?
    let currentStopId: String?
    let status: String?
    let progressPercent: Double?
    let estimated: Bool?
    let timestamp: String?

    enum CodingKeys: String, CodingKey {
        case latitude, longitude, status, estimated, timestamp
        case currentStopName = "current_stop_name"
        case currentStopId = "current_stop_id"
        case progressPercent = "progress_percent"
    }
}
```

- [ ] **Step 2: Add fields to Arrival model in both targets**

In both `Arrival.swift` files, after `let trainEstimated: Bool?`, add:

```swift
var trainCurrentStopId: String? = nil
var trainPositionTimestamp: String? = nil
```

Using `var` with defaults so existing `Arrival(...)` callsites (offline builders, previews) don't break.

Update `withPlatform()` in both targets — add after `trainEstimated: trainEstimated,`:

```swift
trainCurrentStopId: trainCurrentStopId,
trainPositionTimestamp: trainPositionTimestamp,
```

- [ ] **Step 3: Map new fields in GTFSRealtimeMapper in both targets**

In both `GTFSRealtimeMapper.swift` files, in the `Arrival(...)` init, after `trainEstimated: departure.trainPosition?.estimated,`, add:

```swift
trainCurrentStopId: departure.trainPosition?.currentStopId,
trainPositionTimestamp: departure.trainPosition?.timestamp,
```

- [ ] **Step 4: Build both targets**

```bash
xcodebuild -project WatchTrans.xcodeproj -scheme "WatchTrans iOS" -destination "generic/platform=iOS" -quiet build
xcodebuild -project WatchTrans.xcodeproj -target "WatchTrans Watch App" -destination "generic/platform=watchOS" build 2>&1 | grep "error:" | grep -v "ActivityKit"
```

Expected: No errors.

- [ ] **Step 5: Commit and push**

```bash
git add "WatchTrans iOS/Services/GTFSRT/WatchTransModels.swift" \
       "WatchTrans Watch App/Services/GTFSRT/WatchTransModels.swift" \
       "WatchTrans iOS/Models/Arrival.swift" \
       "WatchTrans Watch App/Models/Arrival.swift" \
       "WatchTrans iOS/Services/GTFSRT/GTFSRealtimeMapper.swift" \
       "WatchTrans Watch App/Services/GTFSRT/GTFSRealtimeMapper.swift"
git commit -m "feat: Add currentStopId and timestamp to TrainPositionResponse"
git push
```

---

## Task 3: Add vehicleLabel to Watch + T.DOBLE headsign cleanup (both targets)

**Files:**
- Modify: `WatchTrans Watch App/Services/GTFSRT/WatchTransModels.swift` (DepartureResponse — add vehicleLabel)
- Modify: `WatchTrans Watch App/Models/Arrival.swift` (add vehicleLabel, isDoubleComposition + withPlatform)
- Modify: `WatchTrans iOS/Models/Arrival.swift` (add isDoubleComposition + withPlatform)
- Modify: `WatchTrans iOS/Services/GTFSRT/GTFSRealtimeMapper.swift` (headsign cleanup + isDoubleComposition)
- Modify: `WatchTrans Watch App/Services/GTFSRT/GTFSRealtimeMapper.swift` (same + vehicleLabel mapping)

- [ ] **Step 1: Add vehicleLabel to Watch DepartureResponse**

In `WatchTrans Watch App/Services/GTFSRT/WatchTransModels.swift`, in `DepartureResponse`:

Add field after `vehicleLon`:
```swift
let vehicleLabel: String?       // Train unit identifier (e.g., "MS-07", or "108,119" for double)
```

Add to CodingKeys:
```swift
case vehicleLabel = "vehicle_label"
```

- [ ] **Step 2: Add vehicleLabel and isDoubleComposition to Watch Arrival**

In `WatchTrans Watch App/Models/Arrival.swift`, after `let vehicleLon: Double?`, add:

```swift
var vehicleLabel: String? = nil
var isDoubleComposition: Bool = false
```

Update `withPlatform()` — add after `vehicleLon: vehicleLon,`:
```swift
vehicleLabel: vehicleLabel,
isDoubleComposition: isDoubleComposition,
```

- [ ] **Step 3: Add isDoubleComposition to iOS Arrival**

In `WatchTrans iOS/Models/Arrival.swift`, after `let vehicleLabel: String?`, add:

```swift
var isDoubleComposition: Bool = false
```

Update `withPlatform()` — add after `vehicleLabel: vehicleLabel`:
```swift
isDoubleComposition: isDoubleComposition
```

(Note: this is the last field, so the previous line `vehicleLabel: vehicleLabel` needs a trailing comma added.)

- [ ] **Step 4: Update iOS GTFSRealtimeMapper — headsign cleanup + isDoubleComposition**

In `WatchTrans iOS/Services/GTFSRT/GTFSRealtimeMapper.swift`, replace the headsign/terminus/destination block (from the headsign debug log through the nil-headsign fallback log) with:

```swift
// Extract and clean headsign (strip /T.DOBLE suffix from Metro Sevilla double compositions)
let rawHeadsign = departure.headsign ?? ""
let isDoubleComposition = departure.vehicleLabel?.contains(",") == true
    || rawHeadsign.uppercased().contains("/T.DOBLE")
let cleanHeadsign = rawHeadsign
    .replacingOccurrences(of: "/T.DOBLE", with: "", options: .caseInsensitive)
    .replacingOccurrences(of: "/T. DOBLE", with: "", options: .caseInsensitive)
    .trimmingCharacters(in: .whitespaces)

DebugLog.log("🚂 [Mapper] \(departure.routeShortName) - headsign: \"\(rawHeadsign)\" -> \"\(cleanHeadsign)\" (double: \(isDoubleComposition), trip: \(departure.tripId))")

// Skip terminus trains (where cleaned headsign = current stop)
if !cleanHeadsign.isEmpty,
   let stopName = currentStopName,
   cleanHeadsign.localizedCaseInsensitiveCompare(stopName) == .orderedSame {
    DebugLog.log("⏭️ [Mapper] Skipping terminus train: \(departure.routeShortName) -> \(cleanHeadsign)")
    continue
}
```

Keep `findLine` and time calculations untouched. Then replace the destination assignment:

```swift
let destination = cleanHeadsign.isEmpty ? "Unknown" : cleanHeadsign

if cleanHeadsign.isEmpty && rawHeadsign.isEmpty {
    DebugLog.log("⚠️ [Mapper] headsign was nil, using fallback: \"\(destination)\"")
}
```

In the `Arrival(...)` init, add after `vehicleLabel`:
```swift
isDoubleComposition: isDoubleComposition,
```

- [ ] **Step 5: Update Watch GTFSRealtimeMapper — same headsign cleanup + vehicleLabel**

Same headsign changes as Step 4 in `WatchTrans Watch App/Services/GTFSRT/GTFSRealtimeMapper.swift`.

Additionally, add to the `Arrival(...)` init:
```swift
vehicleLabel: departure.vehicleLabel,
isDoubleComposition: isDoubleComposition,
```

- [ ] **Step 6: Build both targets**

```bash
xcodebuild -project WatchTrans.xcodeproj -scheme "WatchTrans iOS" -destination "generic/platform=iOS" -quiet build
xcodebuild -project WatchTrans.xcodeproj -target "WatchTrans Watch App" -destination "generic/platform=watchOS" build 2>&1 | grep "error:" | grep -v "ActivityKit"
```

Expected: No errors.

- [ ] **Step 7: Commit and push**

```bash
git add "WatchTrans Watch App/Services/GTFSRT/WatchTransModels.swift" \
       "WatchTrans iOS/Models/Arrival.swift" \
       "WatchTrans Watch App/Models/Arrival.swift" \
       "WatchTrans iOS/Services/GTFSRT/GTFSRealtimeMapper.swift" \
       "WatchTrans Watch App/Services/GTFSRT/GTFSRealtimeMapper.swift"
git commit -m "feat: Clean T.DOBLE from headsign, detect double compositions, add vehicleLabel to Watch"
git push
```

---

## Task 4: Double composition badge in views

**Files:**
- Modify: `WatchTrans iOS/Components/ArrivalRowView.swift`
- Modify: `WatchTrans Watch App/Views/Components/ArrivalCard.swift`

- [ ] **Step 1: Add badge to iOS ArrivalRowView**

In `WatchTrans iOS/Components/ArrivalRowView.swift`, inside the HStack that contains the destination arrow + text, add after the `Text(arrival.destination)` block:

```swift
// Double composition badge
if arrival.isDoubleComposition {
    Text("2x")
        .font(.caption2)
        .fontWeight(.bold)
        .foregroundStyle(.white)
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(Color.blue.opacity(0.7))
        .cornerRadius(3)
}
```

- [ ] **Step 2: Add badge to Watch ArrivalCard**

In `WatchTrans Watch App/Views/Components/ArrivalCard.swift`, inside the HStack that contains lineName + arrow + destination, add after `Text(arrival.destination)`:

```swift
if arrival.isDoubleComposition {
    Text("2x")
        .font(.system(size: 8, weight: .bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 3)
        .padding(.vertical, 1)
        .background(Color.blue.opacity(0.7))
        .cornerRadius(2)
}
```

- [ ] **Step 3: Build both targets**

Expected: Clean build.

- [ ] **Step 4: Commit and push**

```bash
git add "WatchTrans iOS/Components/ArrivalRowView.swift" \
       "WatchTrans Watch App/Views/Components/ArrivalCard.swift"
git commit -m "feat(ui): Show double composition badge (2x) in arrival views"
git push
```
