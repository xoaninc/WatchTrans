# Wheelchair Values Fix — Design Spec

## Problem

The app treats `wheelchair_accessible_static` (GTFS static) with the same value scale as `wheelchair_accessible` (GTFS-RT protobuf), but they use different scales:

| Value | RT (protobuf) | Static (GTFS) |
|-------|--------------|---------------|
| null | No data | No data |
| 0 | — | No info |
| 1 | Unknown | **Accessible** |
| 2 | **Accessible** | **NOT accessible** |
| 3 | **NOT accessible** | — |

The current `wheelchairValue()` helper checks `== 2` for accessible and `== 3` for not accessible on both fields. This means static `1` (accessible) is ignored and static `2` (not accessible) is shown as accessible.

## Solution

Normalize static values to RT scale inside `wheelchairValue()`:
- Static `1` → treat as `2` (accessible in RT scale)
- Static `2` → treat as `3` (not accessible in RT scale)
- Static `0`/`null` → nil (no info)

`wheelchair_boarding` on stops already uses `== 1` for accessible and `== 2` for not accessible in `StopDetailView` — this is correct and does not need changes.

## Files

| File | Target | Change |
|------|--------|--------|
| `WatchTrans iOS/Services/GTFSRT/GTFSRealtimeMapper.swift` | iOS | Fix `wheelchairValue()` helper |
| `WatchTrans Watch App/Services/GTFSRT/GTFSRealtimeMapper.swift` | Watch | Same fix |

## Logic

```
Priority: RT > Static fallback

if RT == 2 → accessible (green)
if RT == 3 → not accessible (red cross)
if RT == 1 or 0 or null → check static:
  if static == 1 → accessible (green)
  if static == 2 → not accessible (red cross)
  if static == 0 or null → no icon
```
