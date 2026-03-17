# Accessibility — 3 Levels Design Spec

**Date:** 2026-03-17
**Status:** Approved
**Scope:** iOS only

## Context

The app shows Tren/Bus/Parking badges in StopDetailView but no accessibility info. The API provides three levels of accessibility data:

1. `wheelchair_boarding` on stops (0=no info, 1=accessible, 2=not accessible)
2. `wheelchair_accessible` on departures (per-train accessibility)
3. `acerca_service` on stops (Adif PMR service, 48 Renfe stations)

The app already has `wheelchairBoarding` on the `Stop` model and `wheelchairAccessible` on `Arrival`, but neither is shown in the UI. `acerca_service` has no model yet.

## Changes

### 1. Station accessibility badge (StopDetailView)

In the badges row (Tren/Bus/Parking area), add after Parking:

- `wheelchairBoarding == 1` → ♿ "Accesible" badge in blue
- `wheelchairBoarding == 2` → ♿ "No accesible" badge in red
- `wheelchairBoarding == 0` or `nil` → nothing

Remove the old `accesibilidad` text field display (line 634-638) — it's redundant.

### 2. Per-train accessibility indicator (ArrivalRowView)

In `ArrivalRowView`, when `arrival.wheelchairAccessible == true`, show a small ♿ icon next to the destination (same area as the "2x" composition badge). Only show when accessible — don't show anything when not accessible (avoid alarm).

### 3. Servicio Acerca PMR (StopDetailView + model)

**New model** — add `AcercaService` struct to `WatchTransModels.swift`:

```swift
struct AcercaService: Codable {
    let noticeTime: String?
    let meetingPoint: String?
    let parking: Bool?
    let anden: Bool?
    let aseos: Bool?
    let vestibulo: Bool?

    enum CodingKeys: String, CodingKey {
        case parking, anden, aseos, vestibulo
        case noticeTime = "notice_time"
        case meetingPoint = "meeting_point"
    }
}
```

**Add to StopResponse** — `let acercaService: AcercaService?` with CodingKey `acerca_service`.

**Add to Stop model** — `let acercaService: AcercaService?`, pass through from StopResponse mapping.

**New section in StopDetailView** — below the badges, when `acercaService` is not nil:

- Header: "Servicio Acerca PMR" with ♿ icon
- Meeting point: "Punto de encuentro: Vestíbulo principal"
- Notice time: "Aviso previo: 12h"
- Facility badges: Parking ✓, Andén ✓, Aseos ✓, Vestíbulo ✓ (only show when true)

Only 48 Renfe stations have this data. Section hidden for all others.

## Files Changed

| File | Change |
|------|--------|
| `WatchTrans iOS/Services/GTFSRT/WatchTransModels.swift` | Add `AcercaService` struct, add `acercaService` to `StopResponse` |
| `WatchTrans iOS/Models/Stop.swift` | Add `acercaService: AcercaService?` |
| `WatchTrans iOS/Services/DataService.swift` | Pass `acercaService` in StopResponse → Stop mapping |
| `WatchTrans iOS/Views/Stop/StopDetailView.swift` | Add ♿ badge, remove old accesibilidad text, add Acerca section |
| `WatchTrans iOS/Components/ArrivalRowView.swift` | Add ♿ icon for accessible trains |

## What This Does NOT Change

- No Watch implementation
- No new API calls (data already comes in existing stop/departures responses)
- No changes to alert logic
