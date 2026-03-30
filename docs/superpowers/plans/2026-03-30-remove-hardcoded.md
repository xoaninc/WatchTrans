# Remove All Hardcoded Operator/Network Strings — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all hardcoded operator names, ID prefixes, section titles, and agency detection with data-driven approach using `agencyId` on Line, `transportType` on Arrival, and API network names.

**Architecture:** Add `agencyId` to `Line` model (populated from route's `agencyId` at creation). Add `transportType` to `Arrival` model (populated from matched `Line` in mapper). Views group lines by `agencyId` and look up network name from API. All operator-specific feature fetches run unconditionally — endpoints return empty when no data.

**Tech Stack:** Swift 6, SwiftUI, MVVM + Observable Services, dual-target (iOS + watchOS)

---

### Task 1: Add `agencyId` to Line model (both targets)

**Files:**
- Modify: `WatchTrans iOS/Models/Line.swift`
- Modify: `WatchTrans Watch App/Models/Line.swift`

- [ ] **Step 1: Add `agencyId` field to iOS Line**

In `WatchTrans iOS/Models/Line.swift`, add after `let nucleo: String`:

```swift
let agencyId: String       // Network code from API (e.g., "MMAD", "RENFE_C10", "CRTM_ML1")
```

- [ ] **Step 2: Add `agencyId` field to Watch Line**

In `WatchTrans Watch App/Models/Line.swift`, add after `let nucleo: String`:

```swift
let agencyId: String       // Network code from API (e.g., "MMAD", "RENFE_C10", "CRTM_ML1")
```

- [ ] **Step 3: Fix all `Line(` init calls in iOS DataService**

In `WatchTrans iOS/Services/DataService.swift`, every `Line(` initializer call needs `agencyId: route.agencyId` (or the equivalent variable). There are 4 locations:

**Line ~1060** (initial creation in `mapRoutesToLines`):
```swift
let line = Line(
    id: lineId,
    name: displayName,
    longName: displayLongName,
    type: transportType,
    colorHex: color,
    nucleo: provinceName,
    agencyId: route.agencyId,  // ADD THIS
    routeIds: [route.id],
    ...
```

**Line ~1085** (final lines creation):
```swift
Line(
    id: value.line.id,
    name: value.line.name,
    longName: value.longName,
    type: value.line.type,
    colorHex: value.line.colorHex,
    nucleo: value.line.nucleo,
    agencyId: value.line.agencyId,  // ADD THIS
    routeIds: value.routeIds,
    ...
```

**Line ~1248** (longName update):
```swift
updatedLines[index] = Line(
    id: line.id,
    name: line.name,
    longName: derived,
    type: line.type,
    colorHex: line.colorHex,
    nucleo: line.nucleo,
    agencyId: line.agencyId,  // ADD THIS
    routeIds: line.routeIds,
    ...
```

Search for any other `Line(` calls with `grep -n "Line(" "WatchTrans iOS/Services/DataService.swift"` and add `agencyId` to each.

- [ ] **Step 4: Fix all `Line(` init calls in Watch DataService**

Same as Step 3 but in `WatchTrans Watch App/Services/DataService.swift`. Search with `grep -n "Line(" "WatchTrans Watch App/Services/DataService.swift"` and add `agencyId: route.agencyId` (or `agencyId: value.line.agencyId`) to each.

- [ ] **Step 5: Fix any remaining `Line(` calls in other files**

Search both targets: `grep -rn "Line(" "WatchTrans iOS/" "WatchTrans Watch App/" --include="*.swift" | grep -v "// " | grep -v "NavigationLink" | grep -v "ForEach" | grep -v "\.line"`. Add `agencyId` parameter to any `Line(` initializer calls found (e.g., in `OfflineScheduleService.swift`, preview code, etc.). For previews/test data, use a placeholder like `agencyId: "PREVIEW"`.

- [ ] **Step 6: Commit**

```bash
git add "WatchTrans iOS/Models/Line.swift" "WatchTrans Watch App/Models/Line.swift" "WatchTrans iOS/Services/DataService.swift" "WatchTrans Watch App/Services/DataService.swift" "WatchTrans iOS/Services/OfflineScheduleService.swift"
git commit -m "feat: Add agencyId field to Line model (both targets)"
```

---

### Task 2: Add `transportType` to Arrival model and mapper (both targets)

**Files:**
- Modify: `WatchTrans iOS/Models/Arrival.swift`
- Modify: `WatchTrans Watch App/Models/Arrival.swift`
- Modify: `WatchTrans iOS/Services/GTFSRT/GTFSRealtimeMapper.swift`
- Modify: `WatchTrans Watch App/Services/GTFSRT/GTFSRealtimeMapper.swift`

- [ ] **Step 1: Add `transportType` to iOS Arrival**

In `WatchTrans iOS/Models/Arrival.swift`, add after `let bikesAllowed: Int?` (last stored property before `withPlatform`):

```swift
var transportType: TransportType = .tren
```

Using `var` with default so existing `Arrival(` calls don't break.

- [ ] **Step 2: Add `transportType` to Watch Arrival**

Same change in `WatchTrans Watch App/Models/Arrival.swift`.

- [ ] **Step 3: Populate `transportType` in iOS mapper**

In `WatchTrans iOS/Services/GTFSRT/GTFSRealtimeMapper.swift`, after `bikesAllowed: departure.bikesAllowed` (line ~117), add:

```swift
transportType: line?.type ?? .tren
```

- [ ] **Step 4: Populate `transportType` in Watch mapper**

Same change in `WatchTrans Watch App/Services/GTFSRT/GTFSRealtimeMapper.swift`.

- [ ] **Step 5: Add `transportType` to `withPlatform` copy method**

In both iOS and Watch `Arrival.swift`, in `func withPlatform`, add `transportType: transportType` to the `Arrival(` call.

- [ ] **Step 6: Commit**

```bash
git add "WatchTrans iOS/Models/Arrival.swift" "WatchTrans Watch App/Models/Arrival.swift" "WatchTrans iOS/Services/GTFSRT/GTFSRealtimeMapper.swift" "WatchTrans Watch App/Services/GTFSRT/GTFSRealtimeMapper.swift"
git commit -m "feat: Add transportType to Arrival model, populate from mapper"
```

---

### Task 3: Remove hardcoded detection from Arrival model (both targets)

**Files:**
- Modify: `WatchTrans iOS/Models/Arrival.swift`
- Modify: `WatchTrans Watch App/Models/Arrival.swift`
- Modify: `WatchTrans iOS/Components/ArrivalRowView.swift`
- Modify: `WatchTrans iOS/Views/Stop/TrainDetailView.swift`

- [ ] **Step 1: Remove `isMetroLine`, `isFrequencyBasedLine`, `isCercaniasLine` from iOS Arrival**

In `WatchTrans iOS/Models/Arrival.swift`, delete these three computed properties entirely (lines ~226-289). They contain all the `.contains("fgc")`, `.contains("renfe")`, `.contains("metro")` hardcoded checks.

- [ ] **Step 2: Remove same from Watch Arrival**

In `WatchTrans Watch App/Models/Arrival.swift`, delete `isMetroLine`, `isFrequencyBasedLine`, `isCercaniasLine`.

- [ ] **Step 3: Fix ArrivalRowView progress bar color**

In `WatchTrans iOS/Components/ArrivalRowView.swift` line ~123, change:

```swift
// OLD:
.tint(arrival.isSuspended ? .red : (arrival.isMetroLine ? lineColor : (arrival.isDelayed ? .orange : .green)))
// NEW:
.tint(arrival.isSuspended ? .red : (arrival.isDelayed ? .orange : .green))
```

- [ ] **Step 4: Fix ArrivalRowView >30 min check**

In `WatchTrans iOS/Components/ArrivalRowView.swift` line ~131, change:

```swift
// OLD:
if arrival.minutesUntilArrival > 30 && !arrival.isCercaniasLine {
// NEW:
if arrival.minutesUntilArrival > 30 && arrival.transportType != .tren {
```

- [ ] **Step 5: Fix TrainDetailView progress bar color**

In `WatchTrans iOS/Views/Stop/TrainDetailView.swift` line ~168, change:

```swift
// OLD:
.tint(arrival.isMetroLine ? lineColor : (arrival.isDelayed ? .orange : .green))
// NEW:
.tint(arrival.isDelayed ? .orange : .green)
```

- [ ] **Step 6: Fix TrainDetailView Metro Sevilla composition check**

In `WatchTrans iOS/Views/Stop/TrainDetailView.swift` line ~53, change:

```swift
// OLD:
if arrival.routeId?.hasPrefix("METRO_SEVILLA") == true {
// NEW: (composition comes from API field vehicleComposition, no need to filter by operator)
if arrival.isDoubleComposition {
```

- [ ] **Step 7: Fix ArrivalRowView Metro Sevilla composition check**

In `WatchTrans iOS/Components/ArrivalRowView.swift` line ~66, change:

```swift
// OLD:
let showsComposition = arrival.isDoubleComposition && arrival.routeId?.hasPrefix("METRO_SEVILLA") == true
// NEW:
let showsComposition = arrival.isDoubleComposition
```

- [ ] **Step 8: Commit**

```bash
git add "WatchTrans iOS/Models/Arrival.swift" "WatchTrans Watch App/Models/Arrival.swift" "WatchTrans iOS/Components/ArrivalRowView.swift" "WatchTrans iOS/Views/Stop/TrainDetailView.swift"
git commit -m "refactor: Remove hardcoded agency detection from Arrival model"
```

---

### Task 4: Rewrite iOS LinesListView — group by agencyId

**Files:**
- Modify: `WatchTrans iOS/Views/Lines/LinesListView.swift`

- [ ] **Step 1: Remove all hardcoded computed properties**

Delete these properties from `LinesListView`:
- `isRodalies`
- `metroSectionTitle`
- `tramSectionTitle`
- `cercaniasLines`
- `metroLines`
- `metroLigeroLines`
- `tramLines`
- `fgcLines`

- [ ] **Step 2: Add data-driven section grouping**

Add this struct and computed property:

```swift
struct LineSection: Identifiable {
    let id: String           // agencyId
    let name: String         // network name from API, fallback to agencyId
    let type: TransportType
    let lines: [Line]
}

private var lineSections: [LineSection] {
    let province = currentProvince
    let filtered: [Line]
    if let province {
        filtered = dataService.filteredLines.filter { $0.nucleo.lowercased() == province }
    } else {
        filtered = dataService.filteredLines
    }

    // Group by agencyId
    let grouped = Dictionary(grouping: filtered) { $0.agencyId }

    // Build sections with network name lookup
    let sections = grouped.map { (agencyId, lines) -> LineSection in
        let networkName = dataService.networks.first { $0.code == agencyId }?.name ?? agencyId
        let type = lines.first?.type ?? .tren
        return LineSection(
            id: agencyId,
            name: networkName,
            type: type,
            lines: sortedNumerically(lines)
        )
    }

    // Sort: by transportType ordinal, then alphabetical by name
    return sections.sorted { a, b in
        let aOrder = transportTypeOrder(a.type)
        let bOrder = transportTypeOrder(b.type)
        if aOrder != bOrder { return aOrder < bOrder }
        return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
    }
}

private func transportTypeOrder(_ type: TransportType) -> Int {
    switch type {
    case .tren: return 0
    case .metro: return 1
    case .tram: return 2
    case .bus: return 3
    case .funicular: return 4
    }
}
```

- [ ] **Step 3: Replace body with single ForEach over sections**

Replace all the individual section blocks (Cercanías, Metro, Metro Ligero, Tram, FGC) with:

```swift
List {
    ForEach(lineSections) { section in
        Section {
            ForEach(section.lines) { line in
                NavigationLink(destination: LineDetailView(
                    line: line,
                    dataService: dataService,
                    locationService: locationService,
                    favoritesManager: favoritesManager
                )) {
                    LineRowView(line: line)
                }
            }
        } header: {
            SectionHeaderWithPlan(
                logo: LogoImageView(
                    type: section.type,
                    height: 18
                ),
                title: section.name,
                onShowPlan: { showingPlanFor = section.type }
            )
        }
    }

    // Empty state
    if lineSections.isEmpty {
        // ... existing empty state code
    }
}
```

- [ ] **Step 4: Update empty state check**

Replace:
```swift
if cercaniasLines.isEmpty && metroLines.isEmpty && metroLigeroLines.isEmpty && tramLines.isEmpty && fgcLines.isEmpty {
```
With:
```swift
if lineSections.isEmpty {
```

- [ ] **Step 5: Commit**

```bash
git add "WatchTrans iOS/Views/Lines/LinesListView.swift"
git commit -m "refactor: Rewrite LinesListView to group by agencyId with API network names"
```

---

### Task 5: Rewrite Watch LinesView — group by agencyId

**Files:**
- Modify: `WatchTrans Watch App/Views/Lines/LinesView.swift`

- [ ] **Step 1: Remove all hardcoded properties**

Delete:
- `isSevilla`
- `metroSectionTitle` (entire switch with "Metro Sevilla", "Metro Bilbao", etc.)
- `tramSectionTitle` (entire switch with "MetroCentro", "Tranvía Zaragoza", etc.)
- `cercaniasLines`, `metroLines`, `metroLigeroLines`, `tramLines`, `fgcLines`
- `isRodalies` (if present)

- [ ] **Step 2: Add same `LineSection` struct and `lineSections` computed property as iOS**

Same logic as Task 4 Step 2, adapted for Watch (uses `dataService.lines` instead of `dataService.filteredLines`, and `compareLineWithType` instead of `sortedNumerically` if that's the Watch sorting function).

```swift
struct LineSection: Identifiable {
    let id: String
    let name: String
    let type: TransportType
    let lines: [Line]
}

private var lineSections: [LineSection] {
    let province = currentProvince
    let filtered: [Line]
    if let province {
        filtered = dataService.lines.filter { $0.nucleo.lowercased() == province }
    } else {
        filtered = dataService.lines
    }

    let grouped = Dictionary(grouping: filtered) { $0.agencyId }

    let sections = grouped.map { (agencyId, lines) -> LineSection in
        let networkName = dataService.networks.first { $0.code == agencyId }?.name ?? agencyId
        let type = lines.first?.type ?? .tren
        return LineSection(
            id: agencyId,
            name: networkName,
            type: type,
            lines: lines.sorted { compareLineWithType($0, $1) }
        )
    }

    return sections.sorted { a, b in
        let aOrder = transportTypeOrder(a.type)
        let bOrder = transportTypeOrder(b.type)
        if aOrder != bOrder { return aOrder < bOrder }
        return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
    }
}

private func transportTypeOrder(_ type: TransportType) -> Int {
    switch type {
    case .tren: return 0
    case .metro: return 1
    case .tram: return 2
    case .bus: return 3
    case .funicular: return 4
    }
}
```

- [ ] **Step 3: Replace body sections with ForEach over lineSections**

Replace all 5 hardcoded section blocks with a single:

```swift
ForEach(lineSections) { section in
    VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 6) {
            LogoImageView(type: section.type, height: 14)
            Text(section.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)

        ForEach(section.lines) { line in
            NavigationLink(destination: LineDetailView(line: line, dataService: dataService, locationService: locationService)) {
                LineRowView(line: line)
            }
            .buttonStyle(.plain)
        }
    }
}
```

- [ ] **Step 4: Update empty state check**

Replace the combined `metroLines.isEmpty && metroLigeroLines.isEmpty && ...` with `lineSections.isEmpty`.

- [ ] **Step 5: Commit**

```bash
git add "WatchTrans Watch App/Views/Lines/LinesView.swift"
git commit -m "refactor: Rewrite Watch LinesView to group by agencyId with API network names"
```

---

### Task 6: Remove hardcoded from DataService (both targets)

**Files:**
- Modify: `WatchTrans iOS/Services/DataService.swift`
- Modify: `WatchTrans Watch App/Services/DataService.swift`

- [ ] **Step 1: Remove `networkDisplayName` and `networkTransportType` from iOS**

In `WatchTrans iOS/Services/DataService.swift`, delete:
- `func networkDisplayName(for transportType: TransportType) -> String?` (~line 491-494)
- `func networkTransportType(_ network: NetworkResponse) -> TransportType` (~line 497-505) with its hardcoded switch

- [ ] **Step 2: Remove `isRodalies` from iOS DataService**

Delete `var isRodalies: Bool` (~line 41) if present.

- [ ] **Step 3: Remove `syntheticTripPrefixes` and its usage from iOS**

Delete `private static let syntheticTripPrefixes = [...]` (~line 2094) and the `if Self.syntheticTripPrefixes.contains(where:)` guard in `fetchTripDetails`. The function becomes:

```swift
func fetchTripDetails(tripId: String) async -> TripDetailResponse? {
    do {
        return try await gtfsRealtimeService.fetchTrip(tripId: tripId)
    } catch {
        DebugLog.log("⚠️ [DataService] Failed to fetch trip \(tripId): \(error)")
        return nil
    }
}
```

- [ ] **Step 4: Remove `guessAgencyId` from iOS DataService**

Delete `private func guessAgencyId(lineCode: String) -> String` (~line 2992-2998) which has hardcoded prefixes like `"RENFE_CERCANIAS"`, `"METRO_SEVILLA"`.

- [ ] **Step 5: Same removals in Watch DataService**

Apply steps 1-4 to `WatchTrans Watch App/Services/DataService.swift`.

- [ ] **Step 6: Commit**

```bash
git add "WatchTrans iOS/Services/DataService.swift" "WatchTrans Watch App/Services/DataService.swift"
git commit -m "refactor: Remove hardcoded network type mappings and synthetic trip prefixes from DataService"
```

---

### Task 7: Remove operator-specific prefix guards from StopDetailView

**Files:**
- Modify: `WatchTrans iOS/Views/Stop/StopDetailView.swift`

- [ ] **Step 1: Remove FGC occupancy prefix check**

At ~line 387, change:

```swift
// OLD:
if stop.id.hasPrefix("FGC_") {
    let occupancy = (try? await dataService.gtfsRealtimeService.fetchVehicleOccupancy(operatorId: "fgc")) ?? []
// NEW: (call for all stops, endpoint returns empty if no data)
let occupancy = (try? await dataService.gtfsRealtimeService.fetchVehicleOccupancy(stopId: stop.id)) ?? []
```

Note: check the `fetchVehicleOccupancy` API — if it requires `operatorId`, the endpoint itself needs to be checked. If it can accept a `stopId` or returns empty for non-FGC stops, remove the guard. If it would error, keep a note in `api-requests-pending.md`.

- [ ] **Step 2: Remove TMB_METRO station occupancy prefix check**

At ~line 423, change:

```swift
// OLD:
if stop.id.hasPrefix("TMB_METRO_") {
    stationOccupancy = (try? await ...fetchStationOccupancy(stopIds: [stop.id])) ?? []
}
// NEW:
stationOccupancy = (try? await dataService.gtfsRealtimeService.fetchStationOccupancy(stopIds: [stop.id])) ?? []
```

- [ ] **Step 3: Remove METRO_SEVILLA equipment/air quality prefix checks**

At ~line 428, change:

```swift
// OLD:
if stop.id.hasPrefix("METRO_SEVILLA_") {
    equipmentStatus = ...
    airQualityData = ...
    if let response = try? await ...fetchRouteOperatingHours(routeId: "METRO_SEVILLA_L1-CE-OQ") {
// NEW:
equipmentStatus = (try? await dataService.gtfsRealtimeService.fetchEquipmentStatus(stopId: stop.id)) ?? []
airQualityData = (try? await dataService.gtfsRealtimeService.fetchMetroSevillaAirQuality()) ?? [:]
```

For `fetchRouteOperatingHours` with hardcoded `"METRO_SEVILLA_L1-CE-OQ"`: this needs the actual route ID of the stop being viewed, not a hardcoded one. Use `display?.normalizedLineIds.first` or the first routeId from the arrival data if available. If no route is available, skip.

- [ ] **Step 4: Remove METRO_ prefix check for accesses fallback**

At ~line 404, change:

```swift
// OLD:
let metroStop = dataService.stops.first { otherStop in
    otherStop.id.hasPrefix("METRO_") &&
    otherStop.name.lowercased() == stop.name.lowercased()
}
// NEW:
let metroStop = dataService.stops.first { otherStop in
    otherStop.transportType == .metro &&
    otherStop.name.lowercased() == stop.name.lowercased() &&
    otherStop.id != stop.id
}
```

- [ ] **Step 5: Commit**

```bash
git add "WatchTrans iOS/Views/Stop/StopDetailView.swift"
git commit -m "refactor: Remove operator-specific prefix guards from StopDetailView"
```

---

### Task 8: Clean up remaining hardcoded in HomeView, JourneyPlannerView, SearchView

**Files:**
- Modify: `WatchTrans iOS/Views/Home/HomeView.swift`
- Modify: `WatchTrans iOS/Views/Journey/JourneyPlannerView.swift`
- Modify: `WatchTrans Watch App/Views/Stop/StopDetailView.swift`

- [ ] **Step 1: Fix HomeView METRO_SEVILLA checks**

In `WatchTrans iOS/Views/Home/HomeView.swift`, search for `METRO_SEVILLA_` (lines ~359, ~638). These check if a stop is Metro Sevilla to show composition info. Replace with checking `arrival.isDoubleComposition` or `stop.transportType == .metro` as appropriate — the composition data comes from the API field, not the operator prefix.

- [ ] **Step 2: Fix HomeView/JourneyPlannerView network type checks**

Lines ~397, ~420 have patterns like:
```swift
if network == "METRO" || network == "ML" || network == "TMB_METRO"
```
These determine icon/color for the journey planner. Replace with checking the `TransportType` of the line/route instead of hardcoded network strings.

- [ ] **Step 3: Fix Watch StopDetailView hardcoded abbreviations**

In `WatchTrans Watch App/Views/Stop/StopDetailView.swift` (~line 266), remove any hardcoded abbreviation mapping like `"Cercanías": "Cerc."`. Use the full network name from API or truncate with `.lineLimit(1)`.

- [ ] **Step 4: Commit**

```bash
git add "WatchTrans iOS/Views/Home/HomeView.swift" "WatchTrans iOS/Views/Journey/JourneyPlannerView.swift" "WatchTrans Watch App/Views/Stop/StopDetailView.swift"
git commit -m "refactor: Remove hardcoded operator checks from HomeView, JourneyPlannerView, Watch StopDetailView"
```

---

### Task 9: Update api-requests-pending.md

**Files:**
- Modify: `docs/api-requests-pending.md`

- [ ] **Step 1: Add pending stop-level capability fields**

Add a new section:

```markdown
## GET /api/gtfs/stops/{id} — operator capability fields

| Campo | Estado | Para qué lo necesita la app |
|-------|--------|---------------------------|
| `has_occupancy` | No existe | Saber si la parada tiene datos de ocupación en tiempo real. Sin este campo la app hace fetch para todas las paradas y el endpoint devuelve vacío. |
| `has_equipment_status` | No existe | Saber si la parada tiene estado de equipos (ascensores, escaleras). Sin este campo la app hace fetch para todas. |
| `has_air_quality` | No existe | Saber si la parada tiene datos de calidad del aire. Sin este campo la app hace fetch para todas. |
```

- [ ] **Step 2: Add pending departures route_type field**

```markdown
## GET /api/gtfs/stops/{id}/departures — route_type

| Campo | Estado | Para qué lo necesita la app |
|-------|--------|---------------------------|
| `route_type` | No existe | Tipo de transporte de la ruta (0=tram, 1=metro, 2=rail). La app lo necesita para decidir formato de hora (>30min). Actualmente lo saca del Line model. |
```

- [ ] **Step 3: Commit**

```bash
git add "docs/api-requests-pending.md"
git commit -m "docs: Add pending API fields for stop capabilities and departure route_type"
```

---

### Task 10: Final sweep — verify no hardcoded strings remain

- [ ] **Step 1: Search for remaining hardcoded operator strings**

Run:
```bash
grep -rn '"METRO_SEVILLA\|"TMB_METRO\|"FGC_\|"RENFE_\|"EUSKOTREN\|"CRTM_ML\|"Cercanías"\|"Rodalies"\|"Metro Ligero"\|"Ferrocarrils\|"Tranvía"\|"MetroCentro"\|\.contains("fgc")\|\.contains("renfe")\|\.contains("metro")\|\.contains("euskotren")' "WatchTrans iOS/" "WatchTrans Watch App/" --include="*.swift" | grep -v "Preview\|#Preview\|DebugLog\|// "
```

Every match must be either:
- The ML badge style check (`CRTM_ML` in `isMetroLigero`) — allowed per spec
- Preview/test data — allowed
- A log message — allowed
- Something that needs fixing — fix it

- [ ] **Step 2: Build project**

Open Xcode and build both iOS and Watch targets. Fix any compilation errors.

- [ ] **Step 3: Final commit if any fixes needed**

```bash
git add -A
git commit -m "fix: Address remaining hardcoded strings found in final sweep"
```
