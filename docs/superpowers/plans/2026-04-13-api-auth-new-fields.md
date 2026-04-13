# API Authentication + New Stop Fields — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Bearer auth to all API requests and integrate new stop fields (bicycle_parking, car_parking, description).

**Architecture:** Single shared `APISecrets.swift` provides the key. `NetworkService` adds `Authorization` header to every request via a private helper. Stop model replaces boolean `hasParking` with tri-state ints. UI shows separate bike/car parking icons and an info popover for stop description.

**Tech Stack:** Swift 6, SwiftUI, URLSession

**Spec:** `docs/superpowers/specs/2026-04-13-api-auth-new-fields-design.md`

---

### Task 1: Create APISecrets.swift + update .gitignore

**Files:**
- Create: `WatchTrans iOS/Services/APISecrets.swift` (add to both iOS and Watch targets in Xcode)
- Modify: `.gitignore`

- [ ] **Step 1: Create APISecrets.swift**

```swift
//
//  APISecrets.swift
//  WatchTrans
//
//  API key for authenticated requests. DO NOT commit this file.
//

import Foundation

enum APISecrets {
    static let apiKey = "wt_app_ios_okeob7mvZwUDTbPPxl9BWdEqspy2OFarpBanGIXxWvQ"
}
```

Write this to `WatchTrans iOS/Services/APISecrets.swift`. This single file will be added to both the iOS and Watch targets in Xcode (shared file, not duplicated).

- [ ] **Step 2: Add to .gitignore**

Append to `.gitignore`:
```
# API secrets
APISecrets.swift
```

- [ ] **Step 3: Add authHeader to APIConfiguration.swift (iOS)**

In `WatchTrans iOS/Services/APIConfiguration.swift`, add inside `struct APIConfiguration` after `static let resourceTimeout`:

```swift
    // MARK: - Authentication
    static let authHeader = "Bearer \(APISecrets.apiKey)"
```

- [ ] **Step 4: Add authHeader to APIConfiguration.swift (Watch)**

Same change in `WatchTrans Watch App/Services/APIConfiguration.swift`.

- [ ] **Step 5: Commit**

```bash
git add .gitignore "WatchTrans iOS/Services/APIConfiguration.swift" "WatchTrans Watch App/Services/APIConfiguration.swift"
git commit -m "feat: add API key config and .gitignore entry"
```

Note: APISecrets.swift is gitignored so it won't be in the commit. This is intentional.

---

### Task 2: Add auth header to NetworkService (iOS)

**Files:**
- Modify: `WatchTrans iOS/Services/Network/NetworkService.swift`

- [ ] **Step 1: Add authorizedRequest helper**

After the `init()` method (line 26), add:

```swift
    /// Create a URLRequest with the API authorization header
    private func authorizedRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(APIConfiguration.authHeader, forHTTPHeaderField: "Authorization")
        return request
    }
```

- [ ] **Step 2: Update performFetch to use auth**

In `performFetch<T>` (line ~60), replace:
```swift
let (data, response) = try await session.data(from: url)
```
with:
```swift
let (data, response) = try await session.data(for: authorizedRequest(for: url))
```

- [ ] **Step 3: Update performFetchData to use auth**

In `performFetchData` (line ~139), replace:
```swift
let (data, response) = try await session.data(from: url)
```
with:
```swift
let (data, response) = try await session.data(for: authorizedRequest(for: url))
```

- [ ] **Step 4: Update performPostData to include auth**

In `performPostData` (line ~197), after `request.httpBody = body` add the auth header before the custom headers loop:
```swift
request.setValue(APIConfiguration.authHeader, forHTTPHeaderField: "Authorization")
```

- [ ] **Step 5: Commit**

```bash
git add "WatchTrans iOS/Services/Network/NetworkService.swift"
git commit -m "feat(ios): add Bearer auth to all NetworkService requests"
```

---

### Task 3: Add auth header to NetworkService (Watch)

**Files:**
- Modify: `WatchTrans Watch App/Services/Network/NetworkService.swift`

Identical changes to Task 2. The Watch NetworkService has the same structure.

- [ ] **Step 1: Add authorizedRequest helper after init()**

```swift
    private func authorizedRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(APIConfiguration.authHeader, forHTTPHeaderField: "Authorization")
        return request
    }
```

- [ ] **Step 2: Update performFetch — replace `session.data(from: url)` with `session.data(for: authorizedRequest(for: url))`**

- [ ] **Step 3: Update performFetchData — same replacement**

- [ ] **Step 4: Update performPostData — add auth header before custom headers loop**

- [ ] **Step 5: Commit**

```bash
git add "WatchTrans Watch App/Services/Network/NetworkService.swift"
git commit -m "feat(watch): add Bearer auth to all NetworkService requests"
```

---

### Task 4: Update Stop model (iOS)

**Files:**
- Modify: `WatchTrans iOS/Models/Stop.swift`

- [ ] **Step 1: Replace hasParking and add new fields**

Replace these three properties (lines 20-22):
```swift
    let hasParking: Bool
    let hasBusConnection: Bool
    let hasMetroConnection: Bool
```
with:
```swift
    let bicycleParking: Int    // 0=unknown, 1=available, 2=confirmed
    let carParking: Int        // 0=unknown, 1=available, 2=confirmed
    let stopDescription: String? // Station description/address from API
    // let zoneId: String?     // TODO: Zona tarifaria — pending UI implementation
```

- [ ] **Step 2: Update init parameters**

Replace the init parameter list. Change:
```swift
         hasParking: Bool = false, hasBusConnection: Bool = false, hasMetroConnection: Bool = false,
```
to:
```swift
         bicycleParking: Int = 0, carParking: Int = 0, stopDescription: String? = nil,
```

And in the init body, replace:
```swift
        self.hasParking = hasParking
        self.hasBusConnection = hasBusConnection
        self.hasMetroConnection = hasMetroConnection
```
with:
```swift
        self.bicycleParking = bicycleParking
        self.carParking = carParking
        self.stopDescription = stopDescription
```

- [ ] **Step 3: Update CodingKeys**

Replace:
```swift
        case hasParking = "has_parking"
        case hasBusConnection = "has_bus_connection"
        case hasMetroConnection = "has_metro_connection"
```
with:
```swift
        case bicycleParking = "bicycle_parking"
        case carParking = "car_parking"
        case stopDescription = "description"
```

- [ ] **Step 4: Update init(from decoder:)**

Replace:
```swift
        hasParking = try container.decodeIfPresent(Bool.self, forKey: .hasParking) ?? false
        hasBusConnection = try container.decodeIfPresent(Bool.self, forKey: .hasBusConnection) ?? false
        hasMetroConnection = try container.decodeIfPresent(Bool.self, forKey: .hasMetroConnection) ?? false
```
with:
```swift
        bicycleParking = try container.decodeIfPresent(Int.self, forKey: .bicycleParking) ?? 0
        carParking = try container.decodeIfPresent(Int.self, forKey: .carParking) ?? 0
        stopDescription = try container.decodeIfPresent(String.self, forKey: .stopDescription)
```

- [ ] **Step 5: Commit**

```bash
git add "WatchTrans iOS/Models/Stop.swift"
git commit -m "feat(ios): replace hasParking with bicycleParking/carParking + add stopDescription"
```

---

### Task 5: Update Stop model (Watch)

**Files:**
- Modify: `WatchTrans Watch App/Models/Stop.swift`

Same changes as Task 4. The Watch Stop has extra field `connectionLineIds` but otherwise same structure.

- [ ] **Step 1: Replace properties (lines 21-23)**

Replace `hasParking`, `hasBusConnection`, `hasMetroConnection` with `bicycleParking: Int`, `carParking: Int`, `stopDescription: String?` and the zoneId comment.

- [ ] **Step 2: Update init parameters and body** — same replacements as Task 4

- [ ] **Step 3: Update CodingKeys**

Replace:
```swift
        case hasParking, hasBusConnection, hasMetroConnection, isHub
```
with:
```swift
        case bicycleParking, carParking, stopDescription, isHub
```

Note: Watch CodingKeys don't use snake_case mappings for these (they use the cache format). But since we're changing the field names, we need to add explicit mappings:
```swift
        case bicycleParking = "bicycle_parking"
        case carParking = "car_parking"
        case stopDescription = "description"
        case isHub
```

- [ ] **Step 4: Update init(from decoder:)** — same replacements as Task 4 Step 4

- [ ] **Step 5: Commit**

```bash
git add "WatchTrans Watch App/Models/Stop.swift"
git commit -m "feat(watch): replace hasParking with bicycleParking/carParking + add stopDescription"
```

---

### Task 6: Update WatchTransModels.swift (iOS)

**Files:**
- Modify: `WatchTrans iOS/Services/GTFSRT/WatchTransModels.swift`

- [ ] **Step 1: Update StopResponse (line 367)**

Replace `parkingBicis: String?` (line 380) with:
```swift
    let bicycleParking: Int?
    let carParking: Int?
    let stopDescription: String?
```

Update CodingKeys — replace:
```swift
        case parkingBicis = "parking_bicis"
```
with:
```swift
        case bicycleParking = "bicycle_parking"
        case carParking = "car_parking"
        case stopDescription = "description"
```

- [ ] **Step 2: Update StopFullDetailResponse (line 1453)**

Replace `parkingBicis: String?` (line 1459) with:
```swift
    let bicycleParking: Int?
    let carParking: Int?
    let stopDescription: String?
```

Update CodingKeys — replace:
```swift
        case parkingBicis = "parking_bicis"
```
with:
```swift
        case bicycleParking = "bicycle_parking"
        case carParking = "car_parking"
        case stopDescription = "description"
```

- [ ] **Step 3: Update BranchStopInfo (line 241)**

Add after `wheelchairBoarding`:
```swift
    let bicycleParking: Int?
    let carParking: Int?
```

Add to CodingKeys:
```swift
        case bicycleParking = "bicycle_parking"
        case carParking = "car_parking"
```

- [ ] **Step 4: Commit**

```bash
git add "WatchTrans iOS/Services/GTFSRT/WatchTransModels.swift"
git commit -m "feat(ios): update StopResponse/StopFullDetail/BranchStopInfo with new parking fields"
```

---

### Task 7: Update WatchTransModels.swift (Watch)

**Files:**
- Modify: `WatchTrans Watch App/Services/GTFSRT/WatchTransModels.swift`

Same changes as Task 6 — StopResponse, BranchStopInfo. Check if Watch has StopFullDetailResponse (it might not).

- [ ] **Step 1: Update StopResponse** — same as Task 6 Step 1
- [ ] **Step 2: Update StopFullDetailResponse** (if exists) — same as Task 6 Step 2
- [ ] **Step 3: Update BranchStopInfo** — same as Task 6 Step 3
- [ ] **Step 4: Commit**

```bash
git add "WatchTrans Watch App/Services/GTFSRT/WatchTransModels.swift"
git commit -m "feat(watch): update StopResponse/BranchStopInfo with new parking fields"
```

---

### Task 8: Update DataService mapping (iOS)

**Files:**
- Modify: `WatchTrans iOS/Services/DataService.swift`

- [ ] **Step 1: Update main Stop mapping (line ~255)**

Replace:
```swift
                    hasParking: response.parkingBicis != nil && response.parkingBicis != "0",
                    hasBusConnection: response.corBus != nil && response.corBus != "0",
                    hasMetroConnection: response.corMetro != nil && response.corMetro != "0",
```
with:
```swift
                    bicycleParking: response.bicycleParking ?? 0,
                    carParking: response.carParking ?? 0,
                    stopDescription: response.stopDescription,
```

- [ ] **Step 2: Search for ALL other Stop() initializations in DataService**

Run: `grep -n "hasParking\|parkingBicis" "WatchTrans iOS/Services/DataService.swift"`

Update every occurrence. There may be other mappings where stops are created from different response types (e.g., StopFullDetailResponse). Each one needs the same change.

- [ ] **Step 3: Commit**

```bash
git add "WatchTrans iOS/Services/DataService.swift"
git commit -m "feat(ios): update DataService Stop mapping for new parking fields"
```

---

### Task 9: Update DataService mapping (Watch)

**Files:**
- Modify: `WatchTrans Watch App/Services/DataService.swift`

- [ ] **Step 1: Update ALL Stop() initializations**

There are at least 4 occurrences (lines ~251, ~320, ~398, ~952). Replace `hasParking: response.parkingBicis != nil && response.parkingBicis != "0"` with `bicycleParking: response.bicycleParking ?? 0, carParking: response.carParking ?? 0, stopDescription: response.stopDescription,` in each.

Also replace `hasBusConnection:` and `hasMetroConnection:` params if present.

For the occurrence at line ~398 that copies from an existing stop (`hasParking: s.hasParking`), change to `bicycleParking: s.bicycleParking, carParking: s.carParking, stopDescription: s.stopDescription,`.

- [ ] **Step 2: Commit**

```bash
git add "WatchTrans Watch App/Services/DataService.swift"
git commit -m "feat(watch): update DataService Stop mapping for new parking fields"
```

---

### Task 10: Update StopDetailView parking icons (iOS)

**Files:**
- Modify: `WatchTrans iOS/Views/Stop/StopDetailView.swift`

- [ ] **Step 1: Replace parking block in StopHeaderView (~line 675)**

Replace:
```swift
                    if stop.hasParking {
                        Label("Parking Bici", systemImage: "bicycle")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
```
with:
```swift
                    if stop.bicycleParking >= 1 {
                        Label("Parking Bici", systemImage: "bicycle")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    if stop.carParking >= 1 {
                        Label("Parking", systemImage: "p.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
```

- [ ] **Step 2: Commit**

```bash
git add "WatchTrans iOS/Views/Stop/StopDetailView.swift"
git commit -m "feat(ios): show separate bike/car parking icons in stop header"
```

---

### Task 11: Add description info button (iOS)

**Files:**
- Modify: `WatchTrans iOS/Views/Stop/StopDetailView.swift`

- [ ] **Step 1: Add @State to StopHeaderView**

Add to the `StopHeaderView` struct (after line 604):
```swift
    @State private var showDescription = false
```

- [ ] **Step 2: Add info button next to stop name**

In StopHeaderView body, the stop name is at line ~609:
```swift
                Text(stop.name)
                    .font(.title2)
                    .fontWeight(.bold)
```

Wrap the name in an HStack and add the info button:
```swift
                HStack(spacing: 6) {
                    Text(stop.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    if stop.stopDescription != nil {
                        Button {
                            showDescription.toggle()
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showDescription) {
                            Text(stop.stopDescription ?? "")
                                .font(.body)
                                .padding()
                                .presentationCompactAdaptation(.popover)
                        }
                    }
                }
```

- [ ] **Step 3: Commit**

```bash
git add "WatchTrans iOS/Views/Stop/StopDetailView.swift"
git commit -m "feat(ios): add info button with stop description popover"
```

---

### Task 12: Update Watch StopDetailView

**Files:**
- Modify: `WatchTrans Watch App/Views/Stop/StopDetailView.swift`

- [ ] **Step 1: Fix the preview/mock Stop initialization (~line 272)**

Replace `hasParking: true, hasBusConnection: true, hasMetroConnection: true,` with:
```swift
bicycleParking: 1, carParking: 1,
```

- [ ] **Step 2: Commit**

```bash
git add "WatchTrans Watch App/Views/Stop/StopDetailView.swift"
git commit -m "feat(watch): update Stop mock for new parking fields"
```

---

### Task 13: Fix any remaining compilation errors

**Files:**
- Any file referencing `hasParking`, `hasBusConnection`, `hasMetroConnection`, or `parkingBicis`

- [ ] **Step 1: Search for leftover references in iOS target**

Run: `grep -rn "hasParking\|hasBusConnection\|hasMetroConnection\|parkingBicis" "WatchTrans iOS/"`

Fix any remaining references.

- [ ] **Step 2: Search for leftover references in Watch target**

Run: `grep -rn "hasParking\|hasBusConnection\|hasMetroConnection\|parkingBicis" "WatchTrans Watch App/"`

Fix any remaining references.

- [ ] **Step 3: Search in widget targets**

Run: `grep -rn "hasParking\|hasBusConnection\|hasMetroConnection\|parkingBicis" "WatchTransWidget/" "atchTransWidgetiOSExtension/"`

Fix any remaining references.

- [ ] **Step 4: Commit all fixes**

```bash
git add -A
git commit -m "fix: resolve remaining references to removed parking fields"
```

---

### Task 14: Build verification

- [ ] **Step 1: Build iOS target**

Run: `xcodebuild -project WatchTrans.xcodeproj -scheme "WatchTrans iOS" -destination "platform=iOS Simulator,name=iPhone 16" build 2>&1 | tail -5`

Expected: `BUILD SUCCEEDED`

- [ ] **Step 2: Build Watch target**

Run: `xcodebuild -project WatchTrans.xcodeproj -scheme "WatchTrans Watch App" -destination "platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)" build 2>&1 | tail -5`

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: If build fails, fix errors and commit**

- [ ] **Step 4: Push**

```bash
git push
```
