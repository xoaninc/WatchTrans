# Known Issues Cleanup — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 5 remaining known issues: clean dead NetworkResponse fields, add missing StopFullDetailResponse fields, add pathway mode icons, filter is_skipped departures, handle is_alternative_service.

**Architecture:** Model cleanup + mapper filter + view icon updates. No new API calls.

**Tech Stack:** Swift, SwiftUI

---

## Task 1: Clean NetworkResponse dead fields (both targets)

**Files:**
- Modify: `WatchTrans iOS/Services/GTFSRT/WatchTransModels.swift`
- Modify: `WatchTrans Watch App/Services/GTFSRT/WatchTransModels.swift`

API only sends: `code` (as "id"), `name`, `city`, `color`, `text_color`, `route_count`, `transport_type`.
Dead fields to remove: `region`, `logoUrl`, `wikipediaUrl`, `description`, `nucleoIdRenfe`.

- [ ] **Step 1:** Remove dead fields and CodingKeys from `NetworkResponse` in iOS. Keep the tolerant `init(from:)` but remove references to dead fields. `region` currently has a non-optional default `""` — remove it. All callers only use `code`, `name`, `transportType`.

- [ ] **Step 2:** Same in Watch target.

- [ ] **Step 3:** Build both, commit and push.

---

## Task 2: Add missing fields to StopFullDetailResponse (iOS only)

**Files:**
- Modify: `WatchTrans iOS/Services/GTFSRT/WatchTransModels.swift`

API sends `acerca_service`, `service_status`, `suspended_since` but model lacks them.

- [ ] **Step 1:** Add to `StopFullDetailResponse`:

```swift
let acercaService: AcercaService?
let serviceStatus: String?
let suspendedSince: String?
```

Add to CodingKeys:

```swift
case acercaService = "acerca_service"
case serviceStatus = "service_status"
case suspendedSince = "suspended_since"
```

- [ ] **Step 2:** Build, commit and push.

---

## Task 3: Add pathway mode icons 3-6 (iOS)

**Files:**
- Modify: `WatchTrans iOS/Components/StationInteriorSection.swift`

Current `modeIcon` only handles walkway, stairs, elevator, escalator. Missing: moving_sidewalk (3), fare_gate (6).

- [ ] **Step 1:** Update `modeIcon` in `PathwayRow`:

```swift
private var modeIcon: String {
    switch pathway.pathwayModeName {
    case "walkway": return "figure.walk"
    case "stairs": return "figure.stairs"
    case "moving_sidewalk": return "arrow.left.arrow.right"
    case "escalator": return "arrow.up.right"
    case "elevator": return "arrow.up.arrow.down"
    case "fare_gate": return "creditcard"
    default: return "figure.walk"
    }
}
```

- [ ] **Step 2:** Build, commit and push.

---

## Task 4: Filter is_skipped departures (both targets)

**Files:**
- Modify: `WatchTrans iOS/Services/GTFSRT/GTFSRealtimeMapper.swift`
- Modify: `WatchTrans Watch App/Services/GTFSRT/GTFSRealtimeMapper.swift`

When `is_skipped == true`, the train doesn't stop at this station. Must filter before mapping.

- [ ] **Step 1:** In iOS mapper, after the effectiveMinutes guard and before the headsign cleanup, add:

```swift
// Skip departures where the train doesn't stop at this station
if departure.isSkipped == true { continue }
```

- [ ] **Step 2:** Same in Watch mapper.

- [ ] **Step 3:** Build both, commit and push.

---

## Task 5: is_alternative_service icon (iOS)

**Files:**
- Modify: `WatchTrans iOS/Models/Arrival.swift`
- Modify: `WatchTrans iOS/Services/GTFSRT/GTFSRealtimeMapper.swift`
- Modify: `WatchTrans iOS/Components/ArrivalRowView.swift`

When a route has `is_alternative_service == true`, it's a bus replacement. The departure field is `alternative_service_warning`. We already decode it in DepartureResponse. Need to propagate to Arrival and show bus icon.

- [ ] **Step 1:** Add to iOS Arrival model (var with default):

```swift
var isAlternativeService: Bool = false
```

Update `withPlatform()` to pass it through.

- [ ] **Step 2:** In iOS mapper, after `pmrWarning`, add:

```swift
isAlternativeService: departure.alternativeServiceWarning ?? false
```

- [ ] **Step 3:** In ArrivalRowView, near the line badge area, when `isAlternativeService == true`, show bus icon:

```swift
if arrival.isAlternativeService {
    Image(systemName: "bus.fill")
        .font(.caption)
        .foregroundStyle(.orange)
}
```

- [ ] **Step 4:** Build, commit and push.

---

## Task 6: Update KNOWN_ISSUES

- [ ] **Step 1:** Mark all 5 issues as resolved. Commit and push.
