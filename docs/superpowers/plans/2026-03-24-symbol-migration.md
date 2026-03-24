# Symbol Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace SF Symbols with custom ISO 7001/AIGA assets for transport, accessibility, and stair icons across the entire app.

**Architecture:** Create a `SymbolView` SwiftUI helper for consistent rendering of custom assets. Replace every `Image(systemName:)` / `Label(systemImage:)` for affected symbols. Use `NegatedSymbolView` (symbol + Red Cross overlay) for "is NOT" states.

**Tech Stack:** Swift 6, SwiftUI, Xcode asset catalogs (template-rendered SVGs)

**Build command:** `xcodebuild -project WatchTrans.xcodeproj -scheme "WatchTrans iOS" -destination "generic/platform=iOS" -quiet build 2>&1 | grep -E "error:|BUILD"`

**Reference:** `WatchTrans iOS/Assets.xcassets/CustomSymbols/SYMBOLS.md`

---

## What changes

| SF Symbol | Replace with | Scope |
|-----------|-------------|-------|
| `tram.fill` | `TrenSymbol` (ISO 7001 PI TF 002) | ~15 files |
| `tram.tunnel.fill` | `MetroSymbol` (ISO 7001 PI TF 003) | ~5 files |
| `lightrail.fill` / `tram` | `TramSymbol` (ISO 7001 PI TF 007) | ~5 files |
| `bus.fill` | `BusSymbol` (ISO 7001 PI TF 006) | ~5 files |
| `figure.roll` | `WheelchairSymbol` (ISO 7001 PI PF 006) | ~10 files |
| `figure.roll` + `xmark` overlay | `NegatedSymbolView` (Wheelchair + Red Cross) | ~5 files |
| `StairsSymbol` (AIGA) in PathwayRow | `StairClimbingSymbol` (custom) | 1 file |
| `cablecar.fill` for `.tranvia` | `TramSymbol` (bug fix) | 1 file |
| `door.left.hand.open` in map pins | `StairClimbingSymbol` (all pins = entrance) | 1 file |

## What does NOT change

- `train.side.front.car` — used for Vía/Andén, not a transport mode
- `figure.walk` — stays as SF Symbol
- `bicycle` — stays as SF Symbol
- `door.left.hand.open` in JourneyPlannerView — stays (entrance/exit labels)
- `moon.zzz.fill` — stays (nightly shutdown)
- All UI symbols (star, clock, chevron, location, icloud, etc.) — stay
- All air quality symbols (aqi, thermometer, humidity, leaf) — stay
- All occupancy symbols (person, person.2, person.3) — stay
- `ElevatorSymbol`, `EscalatorSymbol`, `EscalatorUpSymbol`, `EscalatorDownSymbol` — already custom, stay

## Important rules

- Custom assets use `.renderingMode(.template)` for tinting via `.foregroundStyle()`
- Red Cross overlay = "is NOT" (e.g. train is not accessible). NOT for "out of service" (that's red color) or "doesn't exist" (no icon shown)
- Colors: metro=orange, tren=blue, tram=green, bus=red, funicular=brown
- Fuera de servicio = red `.foregroundStyle(.red)` on the symbol itself (no overlay)
- Both iOS and Watch targets must be updated
- Widget targets need assets copied to their asset catalogs

---

## Task 0: Fix preexisting build error

**Files:**
- Modify: `WatchTrans iOS/Views/Map/FullMapView.swift`

- [ ] **Step 1:** Read `FullMapView.swift` around line 428. The `networkName` function references `dataService` which is not in scope inside `LineFilterSheet`. Fix it.
- [ ] **Step 2:** Build and verify: `** BUILD SUCCEEDED **`
- [ ] **Step 3:** Commit and push

---

## Task 1: Create SymbolView helper + RedCrossOverlay asset

**Files:**
- Create: `WatchTrans iOS/Components/SymbolView.swift`
- Create: `WatchTrans iOS/Assets.xcassets/CustomSymbols/RedCrossOverlay.imageset/`

- [ ] **Step 1:** Create `SymbolView.swift`:

```swift
import SwiftUI

struct SymbolView: View {
    let name: String
    var size: CGFloat = 16

    var body: some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

struct NegatedSymbolView: View {
    let name: String
    var size: CGFloat = 16

    var body: some View {
        ZStack {
            SymbolView(name: name, size: size)
            SymbolView(name: "RedCrossOverlay", size: size)
        }
    }
}
```

- [ ] **Step 2:** Create `RedCrossOverlay.imageset` — copy `iso_7001_wikimedia_svg/ISO_7001_-_Red_Cross.svg` into a new imageset with `template-rendering-intent: template`.

- [ ] **Step 3:** Build, commit, push.

---

## Task 2: Replace `figure.roll` → `WheelchairSymbol` (iOS target)

**Files:**
- Modify: `WatchTrans iOS/Components/ArrivalRowView.swift` (~7 occurrences)
- Modify: `WatchTrans iOS/Views/Stop/TrainDetailView.swift` (~3 occurrences)
- Modify: `WatchTrans iOS/Views/Stop/StopDetailView.swift` (~5 occurrences)
- Modify: `WatchTrans iOS/Components/EquipmentStatusSection.swift` (1 occurrence, header)
- Modify: `WatchTrans iOS/Components/StationInteriorSection.swift` (1 occurrence, not-accessible overlay)

For each file:
- [ ] **Step 1:** `Image(systemName: "figure.roll")` → `SymbolView(name: "WheelchairSymbol", size: <match existing font size>)`
- [ ] **Step 2:** `ZStack { Image("figure.roll") Image("xmark") }` → `NegatedSymbolView(name: "WheelchairSymbol", size: <match>)` with `.foregroundStyle(.red)`
- [ ] **Step 3:** `Label("Accesible", systemImage: "figure.roll")` → `HStack(spacing: 4) { SymbolView(name: "WheelchairSymbol", size: 12) Text("Accesible") }`
- [ ] **Step 4:** In StopDetailView map pins (line ~97): replace `access.wheelchair == true ? "figure.roll" : "door.left.hand.open"` with `StairClimbingSymbol` for ALL pins. Accessibility indicated by badge, not pin icon.
- [ ] **Step 5:** Build, commit, push.

---

## Task 3: Replace transport SF Symbols → ISO 7001 (iOS views)

**Files:**
- Modify: `WatchTrans iOS/Views/Stop/StopDetailView.swift` (transport badges switch)
- Modify: `WatchTrans iOS/Views/Stop/TrainDetailView.swift` (tram.fill)
- Modify: `WatchTrans iOS/Components/ArrivalRowView.swift` (tram.fill, bus.fill)
- Modify: `WatchTrans iOS/Views/Map/TrainAnnotationView.swift` (tram.fill)
- Modify: `WatchTrans iOS/Views/Map/FullMapView.swift` (transportIcon function + callers)
- Modify: `WatchTrans iOS/Views/Lines/LinesListView.swift` (bus.fill)

For each `Image(systemName: "tram.fill")` → `SymbolView(name: "TrenSymbol", size: ...)`.
For each `Image(systemName: "tram.tunnel.fill")` → `SymbolView(name: "MetroSymbol", size: ...)`.
For each `Image(systemName: "lightrail.fill")` → `SymbolView(name: "TramSymbol", size: ...)`.
For each `Image(systemName: "bus.fill")` → `SymbolView(name: "BusSymbol", size: ...)`.
For `Label(systemImage:)` → `HStack { SymbolView(...) Text(...) }`.

**FullMapView.transportIcon():** Returns a String. Change to return asset name, and update callers from `Image(systemName: transportIcon(type))` to `SymbolView(name: transportIcon(type))`.

- [ ] **Step 1-6:** Replace in each file.
- [ ] **Step 7:** Build, commit, push.

---

## Task 4: Replace transport SF Symbols in Journey planner (iOS)

**Files:**
- Modify: `WatchTrans iOS/Models/Journey.swift` (TransportMode.icon)
- Modify: `WatchTrans iOS/Views/Journey/JourneyPlannerView.swift`
- Modify: `WatchTrans iOS/Views/Journey/Journey3DAnimationView.swift`
- Modify: `WatchTrans iOS/Views/Journey/NativeAnimatedMapView.swift`

- [ ] **Step 1:** `Journey.swift` — Change `TransportMode.icon` to return asset names. Add `var isCustomAsset: Bool` (false for `.walking`). `.metroLigero` → returns `"MetroSymbol"`.
- [ ] **Step 2:** Fix `cablecar.fill` bug — `.tranvia` case returns `"TramSymbol"` not `"cablecar.fill"`.
- [ ] **Step 3:** Update all callers of `segment.transportMode.icon` to check `isCustomAsset` and use `SymbolView` or `Image(systemName:)` accordingly.
- [ ] **Step 4:** `NativeAnimatedMapView` uses `UIImage(systemName:)` — change to `UIImage(named:)` for custom assets. Guard against nil.
- [ ] **Step 5:** Build, commit, push.

---

## Task 5: Replace SF Symbols in Settings, Intents, LogoImageView (iOS)

**Files:**
- Modify: `WatchTrans iOS/Views/SettingsView.swift`
- Modify: `WatchTrans iOS/Intents/PlanRouteIntent.swift`
- Modify: `WatchTrans iOS/Intents/AppShortcuts.swift`
- Modify: `WatchTrans iOS/Components/LogoImageView.swift`

- [ ] **Step 1:** SettingsView — replace SF Symbols in `relevantCredits` CreditItem icons.
- [ ] **Step 2:** PlanRouteIntent — replace `tram.fill`.
- [ ] **Step 3:** AppShortcuts — `systemImageName: "tram.fill"`. **Note:** AppShortcuts API may require SF Symbols. If custom assets don't work, keep SF Symbol and document exception.
- [ ] **Step 4:** LogoImageView — replace `sfSymbol` property to return custom asset names. Change fallback rendering from `Image(systemName:)` to `Image().renderingMode(.template)`.
- [ ] **Step 5:** Build, commit, push.

---

## Task 6: Replace SF Symbols in Widgets

**Files:**
- Modify: `WatchTransWidget/WatchTransWidget.swift`
- Modify: `WatchTransWidget/TrainLiveActivityWidget.swift`
- Modify: `atchTransWidgetiOS/atchTransWidgetiOS.swift`

**Important:** Widget extensions have their own asset catalogs. Custom imagesets need to be either in a shared asset catalog or duplicated into each widget's catalog.

- [ ] **Step 1:** Check if widgets can access `CustomSymbols/` from the main app's asset catalog. If not, copy needed imagesets to widget asset catalogs.
- [ ] **Step 2:** Replace `tram.fill` in each widget file.
- [ ] **Step 3:** Build widget targets, commit, push.

---

## Task 7: Replace SF Symbols in Watch App

**Files:**
- Create: `WatchTrans Watch App/Components/SymbolView.swift`
- Modify: `WatchTrans Watch App/Views/Stop/TrainDetailView.swift`
- Modify: `WatchTrans Watch App/Views/Components/ArrivalCard.swift`
- Modify: `WatchTrans Watch App/Views/Components/LogoImageView.swift`

- [ ] **Step 1:** Copy `SymbolView.swift` to Watch target.
- [ ] **Step 2:** Copy custom imagesets (`MetroSymbol`, `TrenSymbol`, `TramSymbol`, `BusSymbol`, `FunicularSymbol`, `WheelchairSymbol`, `RedCrossOverlay`, `StairClimbingSymbol`) to `WatchTrans Watch App/Assets.xcassets/`.
- [ ] **Step 3:** Replace `tram.fill` and `figure.roll` in Watch views.
- [ ] **Step 4:** Replace `sfSymbol` in Watch LogoImageView.
- [ ] **Step 5:** Build Watch target, commit, push.

---

## Task 8: Replace StairsSymbol → StairClimbingSymbol in PathwayRow

**Files:**
- Modify: `WatchTrans iOS/Components/StationInteriorSection.swift`

- [ ] **Step 1:** In `PathwayRow.modeIcon`, change `case "stairs": return "StairsSymbol"` to `case "stairs": return "StairClimbingSymbol"`.
- [ ] **Step 2:** Build, commit, push.

---

## Task 9: Remove unused pathway mode icons from PathwayRow

**Files:**
- Modify: `WatchTrans iOS/Components/StationInteriorSection.swift`

- [ ] **Step 1:** Remove from `modeIcon` switch: `case "moving_sidewalk"`, `case "escalator"`, `case "elevator"`, `case "fare_gate"`. These pathway modes don't exist in any API response. Escalator/elevator are only used in `EquipmentStatusSection` (separate code).
- [ ] **Step 2:** Clean up `isCustomAssetIcon` accordingly.
- [ ] **Step 3:** Build, commit, push.

---

## Task 10: Update documentation

**Files:**
- Modify: `WatchTrans iOS/Assets.xcassets/CustomSymbols/SYMBOLS.md`
- Modify: `KNOWN_ISSUES.md`

- [ ] **Step 1:** SYMBOLS.md — mark all migrations ✅, remove "pendiente" flags, update locations.
- [ ] **Step 2:** KNOWN_ISSUES.md — mark resolved: map pins bug, cablecar.fill bug, pathway modes cleanup.
- [ ] **Step 3:** Commit, push.

---

## Task 11: Final verification

- [ ] **Step 1:** Build iOS: expect `** BUILD SUCCEEDED **`
- [ ] **Step 2:** Verify no remaining old SF Symbols:

```bash
grep -rn '"tram\.fill"\|"tram\.tunnel\.fill"\|"lightrail\.fill"\|"bus\.fill"\|"figure\.roll"\|"cablecar\.fill"' \
  "WatchTrans iOS/" "WatchTrans Watch App/" "WatchTransWidget/" "atchTransWidgetiOS/" \
  --include="*.swift" | grep -v "// " | grep -v "SYMBOLS.md"
```

Expected: 0 matches (except possibly AppShortcuts if SF Symbol required there).

- [ ] **Step 3:** Final commit if fixes needed.
