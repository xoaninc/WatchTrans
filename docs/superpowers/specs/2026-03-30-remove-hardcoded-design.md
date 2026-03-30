# Remove All Hardcoded Operator/Network Strings

Date: 2026-03-30

## Problem

The app has 40+ hardcoded operator names, network IDs, ID prefixes, and section titles scattered across views, services, and models. This hides what the API needs to provide, makes the app brittle, and makes it impossible to track what's missing.

## Solution

Replace all hardcoded logic with data-driven approach: group by `agencyId` (which maps to network `code`), use API network names for titles, and use `transportType` from the Line/route for display logic.

## Changes

### 1. Line Model — add `agencyId`

Add `let agencyId: String` to `Line` in both iOS and Watch targets. Populated from `route.agencyId` at creation time in DataService. This is the network `code` from the `/networks` endpoint.

### 2. Lines List Views — group by agencyId

**iOS `LinesListView` and Watch `LinesView`:**

Remove all hardcoded computed properties:
- `cercaniasLines`, `metroLines`, `metroLigeroLines`, `tramLines`, `fgcLines`
- `isRodalies`, `metroSectionTitle`, `tramSectionTitle`
- Watch: `metroSectionTitle` switch (Metro Sevilla, Metro Bilbao, etc.), `tramSectionTitle` switch (MetroCentro, Tranvía Zaragoza, etc.)

Replace with a single computed property that:
1. Filters lines by current province (same as now)
2. Groups by `agencyId`
3. Looks up network name via `dataService.networks.first { $0.code == agencyId }?.name`
4. Falls back to `agencyId` if network name not found (never an invented string)
5. Orders sections: first by `transportType` (tren=0, metro=1, tram=2, bus=3, funicular=4), then alphabetical by network name within each type

Each section gets:
- Title: network name from API
- Logo: `LogoImageView(type: transportType)` (generic icon by transport type)

### 3. Arrival Model — add `transportType`, remove hardcoded detection

Add `transportType: TransportType` to `Arrival`. The mapper populates it from the `Line` it already looks up.

Remove:
- `isMetroLine` (hardcoded `.contains("metro")`, `.contains("fgc")`, etc.)
- `isFrequencyBasedLine` (same hardcoded checks)
- `isCercaniasLine` (hardcoded `.contains("renfe")`, `.contains("sfm")`, `.contains("euskotren")`)

Replace usages:
- Progress bar color: always by delay (green/orange/red) for all operators
- `>30 min` display: `transportType != .tren` (instead of `!isCercaniasLine`)

### 4. DataService — remove network type mappings

Remove:
- `networkDisplayName(for:)` — no longer needed
- `networkTransportType(_:)` — hardcoded switch of "cercanias", "fgc", "metro_ligero", etc.
- Any `isRodalies` logic

### 5. Synthetic Trip Prefixes — remove

Remove `syntheticTripPrefixes = ["MSEV_RT_", "ZGZ_RT_", "TMB_METRO_", "TSEV_RT_"]` from DataService. The fetch attempts, and if it returns 404/nil, the existing fallback in `TrainDetailView` (build journey from route stops) handles it.

### 6. Operator-Specific Feature Checks — remove prefix guards

- `TMB_METRO_` occupancy check → call for all metro stops (routeType 1), endpoint returns empty if no data
- `METRO_SEVILLA_` equipment/air quality → call without prefix filter, endpoints return empty if no data
- Document `has_occupancy`, `has_equipment_status`, `has_air_quality` as pending API fields in `api-requests-pending.md`

### 7. Badge Style — Metro Ligero inverted badge stays

The inverted badge (white bg, colored border) for Metro Ligero lines stays. Detection via `line.id.hasPrefix("CRTM_ML")`. This is the only remaining prefix check — it controls visual style only, not data grouping.

### 8. LineHeaderView `isMetroLigero`

Keep `line.id.hasPrefix("CRTM_ML") || line.name == "R"` for the inverted badge style in `LineHeaderView` and `LineRowView`.

## Files Affected

### iOS
- `Models/Line.swift` — add agencyId
- `Models/Arrival.swift` — add transportType, remove isMetroLine/isCercaniasLine/isFrequencyBasedLine
- `Services/DataService.swift` — populate agencyId, remove networkDisplayName/networkTransportType, remove syntheticTripPrefixes
- `Services/GTFSRT/GTFSRealtimeMapper.swift` — populate transportType on Arrival
- `Views/Lines/LinesListView.swift` — rewrite to group by agencyId
- `Views/Lines/LineDetailView.swift` — remove hardcoded references
- `Views/Stop/StopDetailView.swift` — remove TMB_METRO/METRO_SEVILLA prefix checks
- `Views/Stop/TrainDetailView.swift` — remove synthetic trip check
- `Components/ArrivalRowView.swift` — use transportType instead of isMetroLine/isCercaniasLine

### Watch
- `Models/Line.swift` — add agencyId
- `Models/Arrival.swift` — add transportType, remove hardcoded detection
- `Services/DataService.swift` — same as iOS
- `Services/GTFSRT/GTFSRealtimeMapper.swift` — populate transportType
- `Views/Lines/LinesView.swift` — rewrite to group by agencyId, remove all title switches
- `Views/Stop/StopDetailView.swift` — remove hardcoded abbreviations

### Docs
- `docs/api-requests-pending.md` — add pending fields: `has_occupancy`, `has_equipment_status`, `has_air_quality` for stops; `logo` and `transport_type` for networks (already there)

## Out of Scope

Nothing. All hardcoded strings are in scope except the ML badge style prefix check.
