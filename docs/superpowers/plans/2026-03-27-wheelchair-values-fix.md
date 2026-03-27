# Wheelchair Values Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix wheelchair accessibility value comparison to correctly handle different scales between GTFS-RT (protobuf) and GTFS static fields.

**Architecture:** Normalize static values to RT scale inside the existing `wheelchairValue()` helper in GTFSRealtimeMapper. RT uses 2=accessible/3=not, static uses 1=accessible/2=not. The helper converts static to RT scale before returning.

**Tech Stack:** Swift 6, SwiftUI

**Build command:** `xcodebuild -project WatchTrans.xcodeproj -scheme "WatchTrans iOS" -destination "generic/platform=iOS" -quiet build 2>&1 | grep -E "error:|BUILD"`

**Spec:** `docs/superpowers/specs/2026-03-27-wheelchair-values-fix-design.md`

---

## Task 1: Fix wheelchairValue() in iOS GTFSRealtimeMapper

**Files:**
- Modify: `WatchTrans iOS/Services/GTFSRT/GTFSRealtimeMapper.swift`

- [ ] **Step 1: Read the current helper**

Find `wheelchairValue(rt:static:)` in the file. Current code:

```swift
static func wheelchairValue(rt: Int?, static staticVal: Int?) -> Int? {
    if let rt, rt == 2 || rt == 3 { return rt }
    if let staticVal, staticVal == 2 || staticVal == 3 { return staticVal }
    return nil
}
```

- [ ] **Step 2: Replace with normalized version**

```swift
/// Resolve wheelchair accessibility: RT (protobuf scale) takes priority, fallback to static (GTFS scale).
/// RT: 2=accessible, 3=not accessible. Static: 1=accessible, 2=not accessible.
/// Returns normalized to RT scale: 2=accessible, 3=not accessible, nil=no data.
static func wheelchairValue(rt: Int?, static staticVal: Int?) -> Int? {
    // RT (protobuf): 2=accessible, 3=not accessible
    if let rt, rt == 2 || rt == 3 { return rt }
    // Static (GTFS): 1=accessible, 2=not accessible — normalize to RT scale
    if let staticVal {
        if staticVal == 1 { return 2 }  // accessible → RT 2
        if staticVal == 2 { return 3 }  // not accessible → RT 3
    }
    return nil
}
```

- [ ] **Step 3: Build and verify**

```bash
xcodebuild -project WatchTrans.xcodeproj -scheme "WatchTrans iOS" -destination "generic/platform=iOS" -quiet build 2>&1 | grep -E "error:|BUILD"
```
Expected: no errors

- [ ] **Step 4: Commit**

```bash
git add "WatchTrans iOS/Services/GTFSRT/GTFSRealtimeMapper.swift"
git commit -m "fix: Normalize wheelchair_accessible_static values to RT scale

Static GTFS uses 1=accessible, 2=not accessible.
RT protobuf uses 2=accessible, 3=not accessible.
Helper now converts static to RT scale before returning.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
git push
```

---

## Task 2: Fix wheelchairValue() in Watch GTFSRealtimeMapper

**Files:**
- Modify: `WatchTrans Watch App/Services/GTFSRT/GTFSRealtimeMapper.swift`

- [ ] **Step 1: Apply identical change as Task 1**

Same `wheelchairValue()` helper exists in the Watch target. Replace with the same normalized version.

- [ ] **Step 2: Build iOS (Watch has ActivityKit issues, iOS build confirms shared logic compiles)**

- [ ] **Step 3: Commit**

```bash
git add "WatchTrans Watch App/Services/GTFSRT/GTFSRealtimeMapper.swift"
git commit -m "fix: Normalize wheelchair static values in Watch target (same as iOS)

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
git push
```

---

## Task 3: Verify StopDetailView wheelchair_boarding values

**Files:**
- Read: `WatchTrans iOS/Views/Stop/StopDetailView.swift`

- [ ] **Step 1: Verify wheelchair_boarding comparison**

Search for `wheelchairBoarding` in StopDetailView. It should use `== 1` for accessible and `== 2` for not accessible (GTFS static scale). Confirm this is already correct — no changes needed.

- [ ] **Step 2: Document verification**

If correct, no commit needed. If wrong, fix and commit.

---

## Task 4: Verify with real API data

- [ ] **Step 1: Test Renfe (has RT)**

```bash
curl -s "https://api.watch-trans.app/api/gtfs/stops/RENFE_C_17000/departures" | python3 -c "
import sys, json
deps = json.load(sys.stdin)
for d in deps[:3]:
    print(f'{d[\"route_short_name\"]}: RT={d.get(\"wheelchair_accessible\")}, static={d.get(\"wheelchair_accessible_static\")}')
"
```

- [ ] **Step 2: Test Metro Madrid (static only)**

```bash
curl -s "https://api.watch-trans.app/api/gtfs/stops/METRO_MAD_12_STATION/departures?limit=3" | python3 -c "
import sys, json
deps = json.load(sys.stdin)
for d in deps[:3]:
    print(f'{d[\"route_short_name\"]}: RT={d.get(\"wheelchair_accessible\")}, static={d.get(\"wheelchair_accessible_static\")}')
"
```

Expected: RT=null for non-Renfe, static=1 (accessible) for Metro Madrid.

---

## Task 5: Update documentation

**Files:**
- Modify: `WatchTrans iOS/Assets.xcassets/CustomSymbols/SYMBOLS.md`

- [ ] **Step 1: Update wheelchair value documentation**

In the WheelchairSymbol section, add note about the different scales:
- RT (protobuf): 2=accessible, 3=not accessible
- Static (GTFS): 1=accessible, 2=not accessible
- App normalizes static→RT in `wheelchairValue()` helper

- [ ] **Step 2: Commit**

```bash
git add "WatchTrans iOS/Assets.xcassets/CustomSymbols/SYMBOLS.md"
git commit -m "docs: Document wheelchair value scales (RT vs static)

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
git push
```
