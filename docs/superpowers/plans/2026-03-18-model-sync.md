# Model Sync — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring all Codable models in sync with current API responses — fix broken CodingKeys and add missing fields.

**Architecture:** Pure model changes in `WatchTransModels.swift` (both iOS and Watch targets). No UI changes, no new views, no new fetches. All new fields are optional with `decodeIfPresent` so nothing breaks.

**Tech Stack:** Swift, Codable

**Source of truth:** `/Users/juanmaciasgomez/Projects/WatchTrans_Server/docs/API_ENDPOINTS.md`

---

## Task 1: Fix LineResponse CodingKeys (BREAKING — colors may not decode)

**Files:**
- Modify: `WatchTrans iOS/Services/GTFSRT/WatchTransModels.swift` (LineResponse + LineRouteInfo)
- Modify: `WatchTrans Watch App/Services/GTFSRT/WatchTransModels.swift` (same)

- [ ] **Step 1: Fix LineResponse CodingKeys in iOS**

API sends `route_color` and `route_text_color`. Current CodingKeys use `color` and `text_color`.

In `LineResponse` CodingKeys, change:
```swift
case color, routes
case textColor = "text_color"
```
to:
```swift
case color = "route_color"
case routes
case textColor = "route_text_color"
```

In `LineRouteInfo` CodingKeys, change:
```swift
case id, color
```
to:
```swift
case id
case color = "route_color"
```

- [ ] **Step 2: Same changes in Watch target**

- [ ] **Step 3: Build both targets**

```bash
xcodebuild -project WatchTrans.xcodeproj -scheme "WatchTrans iOS" -destination "generic/platform=iOS" -quiet build
xcodebuild -project WatchTrans.xcodeproj -target "WatchTrans Watch App" -destination "generic/platform=watchOS" build 2>&1 | grep "error:" | grep -v "ActivityKit"
```

- [ ] **Step 4: Commit and push**

```bash
git commit -m "fix: LineResponse CodingKeys — route_color and route_text_color"
git push
```

---

## Task 2: Add missing fields to DepartureResponse (both targets)

**Files:**
- Modify: `WatchTrans iOS/Services/GTFSRT/WatchTransModels.swift` (DepartureResponse)
- Modify: `WatchTrans Watch App/Services/GTFSRT/WatchTransModels.swift` (DepartureResponse)

- [ ] **Step 1: Add fields to iOS DepartureResponse**

After `vehicleLabel`, add:

```swift
// Express service (CIVIS)
let isExpress: Bool?
let expressName: String?
let expressColor: String?

// Accessibility warnings
let wheelchairAccessibleNow: Bool?
let pmrWarning: Bool?
let alternativeServiceWarning: Bool?

// Platform confidence
let platformConfidence: Double?

// Delay estimation
let delayEstimated: Bool?

// Station occupancy (inline, TMB)
let stationOccupancyPct: Int?
let stationOccupancyStatus: Int?
```

Add to CodingKeys:

```swift
case isExpress = "is_express"
case expressName = "express_name"
case expressColor = "express_color"
case wheelchairAccessibleNow = "wheelchair_accessible_now"
case pmrWarning = "pmr_warning"
case alternativeServiceWarning = "alternative_service_warning"
case platformConfidence = "platform_confidence"
case delayEstimated = "delay_estimated"
case stationOccupancyPct = "station_occupancy_pct"
case stationOccupancyStatus = "station_occupancy_status"
```

- [ ] **Step 2: Same changes in Watch DepartureResponse**

- [ ] **Step 3: Add `bearing` and `speed` to TrainPositionResponse (both targets)**

In `TrainPositionResponse`, add:

```swift
let bearing: Double?
let speed: Double?
```

Add to CodingKeys:

```swift
case bearing, speed
```

- [ ] **Step 4: Build both targets**

- [ ] **Step 5: Commit and push**

```bash
git commit -m "feat: Add express, PMR, accessibility, platform confidence to DepartureResponse"
git push
```

---

## Task 3: Fix AlertResponse — severity_level + active_periods phases

**Files:**
- Modify: `WatchTrans iOS/Services/GTFSRT/WatchTransModels.swift` (AlertResponse)
- Modify: `WatchTrans Watch App/Services/GTFSRT/WatchTransModels.swift` (AlertResponse)

- [ ] **Step 1: Verify severity field name**

Check the actual API response to determine if it sends `severity` or `severity_level`:

```bash
curl -s "https://api.watch-trans.app/api/gtfs-rt/alerts?active_only=true&limit=1" | python3 -c "import sys,json; d=json.load(sys.stdin); print([k for k in d[0].keys() if 'sever' in k])"
```

If it sends `severity_level`, update the CodingKey in both targets. If it sends `severity`, no change needed.

- [ ] **Step 2: Add `activePeriods` array model (both targets)**

The API now sends `active_periods` as an array of objects with `effect` and `phase_description`. Replace the flat `activePeriodStart`/`activePeriodEnd` with proper array.

Add new struct before `AlertResponse`:

```swift
struct AlertActivePeriod: Codable {
    let startTime: String?
    let endTime: String?
    let effect: String?
    let phaseDescription: String?

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case effect
        case phaseDescription = "phase_description"
    }
}
```

In `AlertResponse`, add:

```swift
let activePeriods: [AlertActivePeriod]?
```

Add to CodingKeys:

```swift
case activePeriods = "active_periods"
```

Keep `activePeriodStart`/`activePeriodEnd` for backward compat (they still decode from the first period if present).

- [ ] **Step 3: Build both targets**

- [ ] **Step 4: Commit and push**

```bash
git commit -m "feat: Add active_periods phases to AlertResponse, verify severity_level"
git push
```

---

## Task 4: Minor model additions (both targets)

**Files:**
- Modify: `WatchTrans iOS/Services/GTFSRT/WatchTransModels.swift`
- Modify: `WatchTrans Watch App/Services/GTFSRT/WatchTransModels.swift`

- [ ] **Step 1: Add `source` to AcercaService**

```swift
let source: String?
```

Add to CodingKeys:

```swift
case source
```

- [ ] **Step 2: Add `source` to RouteOperatingHoursResponse**

```swift
let source: String?
```

Add to CodingKeys:

```swift
case source
```

- [ ] **Step 3: Add `isCircular` to RouteShapeResponse**

```swift
let isCircular: Bool?
```

Add to CodingKeys:

```swift
case isCircular = "is_circular"
```

- [ ] **Step 4: Add `observationCount` and `lastObserved` to PlatformPredictionResponse**

```swift
let observationCount: Int?
let lastObserved: String?
```

Add to CodingKeys:

```swift
case observationCount = "observation_count"
case lastObserved = "last_observed"
```

Keep `sampleSize` for backward compat (may still be sent by some responses).

- [ ] **Step 5: Build both targets**

- [ ] **Step 6: Commit and push**

```bash
git commit -m "feat: Add source, isCircular, observationCount to minor models"
git push
```

---

## Task 5: Verification — Euskotren colons + CIVIS headsign

- [ ] **Step 1: Verify Euskotren URL encoding**

```bash
curl -s "https://api.watch-trans.app/api/gtfs/stops/EUSKOTREN_ES%3AEuskotren%3AStopPlace%3A1468%3A/departures?limit=1" | head -100
```

If this returns data, `URLComponents` handles it (it auto-encodes). If 404, the app needs manual encoding.

- [ ] **Step 2: Verify CIVIS headsign**

```bash
curl -s "https://api.watch-trans.app/api/gtfs/stops/RENFE_C_18000/departures?limit=20" | python3 -c "import sys,json; [print(d.get('headsign',''), d.get('is_express',False)) for d in json.load(sys.stdin) if d.get('is_express')]"
```

Check if any departure has `headsign="CIVIS"` or if the server already replaces it.

- [ ] **Step 3: Document findings in KNOWN_ISSUES**

Update KNOWN_ISSUES with verification results. If Euskotren works, mark as verified. If CIVIS is server-side handled, mark as non-issue.

- [ ] **Step 4: Commit and push**

```bash
git commit -m "docs: Verify Euskotren URL encoding and CIVIS headsign handling"
git push
```
