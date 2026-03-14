# Station Interior Section — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add "Interior de estación" section to StopDetailView showing accesses, pathways, and vestibules from the station-interior API.

**Architecture:** New `StationInteriorSection` component in `Components/`, same pattern as `EquipmentStatusSection`. Replaces existing inline "Plantas" section and takes precedence over `NearestAccessSectionView` when interior accesses exist.

**Tech Stack:** Swift, SwiftUI

**Spec:** `docs/superpowers/specs/2026-03-14-station-interior-design.md`

---

## Task 1: Add `streetNumber` to `InteriorAccess` model

**Files:**
- Modify: `WatchTrans iOS/Services/GTFSRT/WatchTransModels.swift`

- [ ] **Step 1: Add field and CodingKey**

In `InteriorAccess` struct, add `streetNumber` after `street`:

```swift
let streetNumber: String?
```

Add to CodingKeys:

```swift
case streetNumber = "street_number"
```

- [ ] **Step 2: Build**

```bash
xcodebuild -project WatchTrans.xcodeproj -scheme "WatchTrans iOS" -destination "generic/platform=iOS" -quiet build
```

- [ ] **Step 3: Commit and push**

```bash
git add "WatchTrans iOS/Services/GTFSRT/WatchTransModels.swift"
git commit -m "feat: Add streetNumber to InteriorAccess model"
git push
```

---

## Task 2: Create `StationInteriorSection` component

**Files:**
- Create: `WatchTrans iOS/Components/StationInteriorSection.swift`

- [ ] **Step 1: Create the component**

Create `WatchTrans iOS/Components/StationInteriorSection.swift` with the full component. Structure:

- `StationInteriorSection` — main view, receives `StationInteriorResponse`
  - Header: "Interior de estación" with building icon
  - Conditionally shows 3 subsections based on non-empty arrays
- `AccessRow` — private, renders one access (name, street+streetNumber, wheelchair badge)
- `PathwayRow` — private, renders one pathway (signposted_as or from→to, time badge, mode icon)
- `VestibuleRow` — private, renders one vestibule (name, level, wheelchair)

Key details:
- Accesos: show first 3, rest in DisclosureGroup
- Recorridos: show first 5, rest in DisclosureGroup. Primary text is `signposted_as` when available, fallback to `"\(from_stop_name) → \(to_stop_name)"`. Time badge only when `traversal_time` is not nil.
- Vestíbulos: show all (max ~17, fits fine)
- Pathway mode icons: "walkway" → `figure.walk`, "stairs" → `figure.stairs`, "escalator" → custom `EscalatorSymbol`, "elevator" → custom `ElevatorSymbol`

- [ ] **Step 2: Build**

```bash
xcodebuild -project WatchTrans.xcodeproj -scheme "WatchTrans iOS" -destination "generic/platform=iOS" -quiet build
```

- [ ] **Step 3: Commit and push**

```bash
git add "WatchTrans iOS/Components/StationInteriorSection.swift"
git commit -m "feat: Add StationInteriorSection component for station pathways and accesses"
git push
```

---

## Task 3: Integrate into `StopDetailView`

**Files:**
- Modify: `WatchTrans iOS/Views/Stop/StopDetailView.swift`

- [ ] **Step 1: Replace inline Plantas section with StationInteriorSection**

Find the inline "Station levels" section (the block starting with `// Station levels` and the `if let levels = stationInterior?.levels` check). Replace it with:

```swift
// Station interior (accesses, pathways, vestibules, levels)
if let interior = stationInterior,
   !(interior.pathways ?? []).isEmpty || !(interior.accesses ?? []).isEmpty || !(interior.vestibules ?? []).isEmpty || !(interior.levels ?? []).isEmpty {
    StationInteriorSection(interior: interior)
        .padding(.horizontal)
}
```

- [ ] **Step 2: Conditionally hide NearestAccessSectionView**

Wrap the existing `NearestAccessSectionView` block to only show when interior accesses are NOT available:

```swift
// Navigate to nearest access (hidden when station-interior has accesses)
let interiorHasAccesses = !(stationInterior?.accesses ?? []).isEmpty
if !accesses.isEmpty && !interiorHasAccesses {
    NearestAccessSectionView(
        accesses: accesses,
        userLocation: locationService.currentLocation
    )
}
```

- [ ] **Step 3: Build**

```bash
xcodebuild -project WatchTrans.xcodeproj -scheme "WatchTrans iOS" -destination "generic/platform=iOS" -quiet build
```

- [ ] **Step 4: Commit and push**

```bash
git add "WatchTrans iOS/Views/Stop/StopDetailView.swift"
git commit -m "feat: Integrate StationInteriorSection into StopDetailView"
git push
```
