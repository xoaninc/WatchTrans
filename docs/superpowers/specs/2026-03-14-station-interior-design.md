# Station Interior Section — Design Spec

**Date:** 2026-03-14
**Status:** Approved
**Scope:** iOS only

## Context

The API endpoint `GET /api/gtfs/stops/{stop_id}/station-interior` returns interior data for stations: pathways (internal routes), accesses (entrances with street names), vestibules, and levels. Data is available for Metro Madrid, TMB Barcelona, Renfe Cercanías, Metro Ligero, Euskotren, Metro Valencia, SFM Mallorca, and Metro Málaga.

The app already has the Codable models (`StationInteriorResponse`, `InteriorPathway`, `InteriorAccess`, `StationVestibule`, `StationLevel` in `WatchTransModels.swift`), the fetch method (`GTFSRealtimeService.fetchStationInterior`), and `StopDetailView` already fetches and stores the response in `@State var stationInterior`. What's missing is the UI component.

## Design

A single section "Interior de estación" in `StopDetailView` with up to 3 subsections: Accesos, Recorridos, Vestíbulos. Only shown when the API returns data. Each subsection only appears if its array is non-empty.

### Subsection: Accesos

Shows station entrances with street name and wheelchair badge.

- Icon: door/entrance
- Primary text: access `name` (e.g., "Carretas", "Sol-Ascensor")
- Secondary text: `street` + `streetNumber` (e.g., "Pza. Puerta del Sol, 7")
- Wheelchair badge: green "Accesible" pill when `wheelchair == true`
- Show first 3, remainder in DisclosureGroup

**Model change required:** Add `streetNumber: String?` to `InteriorAccess` with CodingKey `street_number`. Backend is adding this field to the serializer (data exists in DB).

**Data availability:** Metro Madrid (689), Renfe Cercanías (195), Metro Ligero (29).

### Subsection: Recorridos

Shows internal pathways with walking time.

- Primary text: `signposted_as` when available (TMB: "Sortida per Rambla Catalunya", "Correspondència L1 - L3"). Fallback: "`from_stop_name` → `to_stop_name`" (Metro Madrid: "Carretas → Andén 1")
- Time badge: `traversal_time` in seconds (e.g., "53s"). Hidden when nil (Euskotren, Valencia).
- Distance: `length` in meters as secondary text when available.
- `pathway_mode_name` as icon context: "walkway", "stairs", "escalator", "elevator"
- Show first 5, remainder in DisclosureGroup

**Data availability:** Metro Madrid (1,674), TMB (1,065), Euskotren (686, no times), Metro Valencia (186, no times), SFM Mallorca (30), Metro Málaga (6).

### Subsection: Vestíbulos

Shows vestibule areas with level info.

- Primary text: `name` (e.g., "Atocha", "Metro")
- Secondary text: level as "Nivel -1" when `level` is set
- Wheelchair badge when `wheelchair == true`

**Data availability:** Renfe Cercanías (105), Metro Ligero (17).

## Access Section Precedence

`StopDetailView` currently has a `NearestAccessSectionView` that uses the `/accesses` endpoint (`StationAccess` model). The new interior section uses `/station-interior` (`InteriorAccess` model). These are the same data from different sources.

**Rule:** If `stationInterior.accesses` is non-empty, show the interior accesses and hide `NearestAccessSectionView`. If station-interior has no accesses, fall back to the existing `/accesses` section.

## Existing Inline "Plantas" Section

`StopDetailView` lines 185-202 render `stationInterior.levels` inline. This must be removed and moved into `StationInteriorSection` to avoid duplication.

## Component

`StationInteriorSection.swift` in `WatchTrans iOS/Components/`.

```swift
struct StationInteriorSection: View {
    let interior: StationInteriorResponse
}
```

Same pattern as `EquipmentStatusSection` — receives the response, renders subsections.

## Data Flow

1. `StopDetailView` already fetches `stationInterior` and stores it in `@State`
2. If response has any non-empty array → show `StationInteriorSection`
3. If `stationInterior.accesses` non-empty → hide `NearestAccessSectionView`
4. Remove inline "Plantas" section (now handled by component)

No new API calls. No new fetch methods needed.

## Files Changed

| File | Change |
|------|--------|
| `WatchTrans iOS/Components/StationInteriorSection.swift` | NEW — view component |
| `WatchTrans iOS/Views/Stop/StopDetailView.swift` | Replace inline Plantas section with StationInteriorSection, conditionally hide NearestAccessSectionView |
| `WatchTrans iOS/Services/GTFSRT/WatchTransModels.swift` | Add `streetNumber` to `InteriorAccess` |

## What This Does NOT Change

- No Watch implementation
- No new API endpoints
- No new fetch methods (already exists)
- No changes to other views
