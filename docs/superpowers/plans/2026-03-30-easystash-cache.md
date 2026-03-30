# EasyStash Cache Replacement — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace ~300 lines of custom cache code in DataService with a simple `Storage` class (~80 lines) based on the EasyStash pattern.

**Architecture:** A single `Storage` class handles all disk persistence: save/load Codable objects as JSON files, use filesystem `modificationDate` for TTL, no metadata structs. DataService becomes a thin consumer that tries `storage.load()`, catches errors, and falls back to API fetch.

**Tech Stack:** Swift 6, Foundation (FileManager, JSONEncoder/Decoder), no external dependencies

---

### Task 1: Create Storage.swift

**Files:**
- Create: `WatchTrans iOS/Services/Storage.swift`
- Create: `WatchTrans Watch App/Services/Storage.swift`

- [ ] **Step 1: Create Storage.swift for iOS**

Create `WatchTrans iOS/Services/Storage.swift` with this content:

```swift
//
//  Storage.swift
//  WatchTrans
//
//  Simple disk cache: save/load Codable objects as JSON files.
//  Uses filesystem modificationDate for TTL — no metadata structs needed.
//

import Foundation

enum StorageError: Error {
    case notFound
    case expired
    case decodeFailed
}

final class Storage {
    private let folderURL: URL
    private let fileManager: FileManager = .default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(folder: String) {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.folderURL = caches.appendingPathComponent(folder, isDirectory: true)
        try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
    }

    func save<T: Codable>(object: T, forKey key: String) throws {
        let data = try encoder.encode(object)
        let url = fileURL(forKey: key)
        try data.write(to: url)
    }

    func load<T: Codable>(forKey key: String, as type: T.Type, maxAge: TimeInterval) throws -> T {
        let url = fileURL(forKey: key)

        guard fileManager.fileExists(atPath: url.path) else {
            throw StorageError.notFound
        }

        // Check TTL using file modification date
        if maxAge != .infinity {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            guard let modified = attributes[.modificationDate] as? Date else {
                throw StorageError.notFound
            }
            if Date().timeIntervalSince(modified) > maxAge {
                throw StorageError.expired
            }
        }

        let data = try Data(contentsOf: url)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            // Model changed — cache is stale
            try? fileManager.removeItem(at: url)
            throw StorageError.decodeFailed
        }
    }

    func remove(forKey key: String) throws {
        let url = fileURL(forKey: key)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    func removeAll() throws {
        if fileManager.fileExists(atPath: folderURL.path) {
            try fileManager.removeItem(at: folderURL)
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
    }

    func exists(forKey key: String) -> Bool {
        fileManager.fileExists(atPath: fileURL(forKey: key).path)
    }

    private func fileURL(forKey key: String) -> URL {
        folderURL.appendingPathComponent(key, isDirectory: false)
    }
}
```

- [ ] **Step 2: Copy to Watch target**

Copy the exact same file to `WatchTrans Watch App/Services/Storage.swift`.

- [ ] **Step 3: Add both files to Xcode targets**

Add `WatchTrans iOS/Services/Storage.swift` to the iOS target and `WatchTrans Watch App/Services/Storage.swift` to the Watch target in Xcode. If using the filesystem directly, ensure the files are included in the target membership.

- [ ] **Step 4: Commit**

```bash
git add "WatchTrans iOS/Services/Storage.swift" "WatchTrans Watch App/Services/Storage.swift"
git commit -m "feat: Add Storage class — EasyStash-pattern disk cache"
```

---

### Task 2: Replace iOS DataService cache with Storage

**Files:**
- Modify: `WatchTrans iOS/Services/DataService.swift`

This is the big task. Read the file first, then make the changes in order.

- [ ] **Step 1: Add storage property and cache TTL constant**

Near the top of DataService (after the `@Observable` properties), add:

```swift
private let storage = Storage(folder: "WatchTransCache")
private static let cacheTTL: TimeInterval = 24 * 60 * 60  // 24 hours
```

- [ ] **Step 2: Delete old cache infrastructure**

Delete ALL of these (they span lines ~73-440 approximately):

- `stopsCacheDuration`, `linesCacheDuration`, `lineColorsCacheDuration` constants
- `stopsVerifyInterval`, `linesVerifyInterval`, `lineColorsVerifyInterval` constants
- All `static var *CacheURL` computed properties (`stopsCacheURL`, `linesCacheURL`, `locationCacheURL`, `lineColorsCacheURL`, `platformsCacheURL`, `shapeCacheURL`)
- `CacheMetadata` struct
- `LineColorsCacheMetadata` struct
- `stopsCacheMetadata`, `linesCacheMetadata`, `lineColorsCacheMetadata` properties
- `PlatformsCacheEntry` struct and `platformsCache` dict and `platformsCacheTTL`
- `checkAppVersionAndClearCacheIfNeeded()`
- `clearAllCaches()`
- `loadCachedData()` — the big init loader
- `saveStopsCache(coordinatesHash:)`
- `saveLinesCache(coordinatesHash:)`
- `updateLineColorsCache()`
- `saveLocationCache()`
- `savePlatformsCache()`
- `saveShapeCache()`
- `loadLinesFromCache(coordinatesHash:)`
- `shouldVerifyStops()`, `shouldVerifyLines()`
- `updateStopsVerifyTimestamp()`, `updateLinesVerifyTimestamp()`
- `StopsCache`, `LinesCache`, `LineColorsCache` structs

Keep: `coordinatesHash(lat:lon:)` — still needed to generate cache keys. Keep `linesLoaded` flag. Keep `lineColorsCache` dict (in-memory lookup, populated from lines). Keep `shapeCache` dict and `shapeCacheQueue`. Keep `filteredLines` and `getEnabledTransportTypes()`.

- [ ] **Step 3: Replace init**

The current `init()` calls `loadCachedData()`. Replace with:

```swift
init() {
    self.networkService = NetworkService()
    self.gtfsRealtimeService = GTFSRealtimeService(networkService: networkService)
    loadFromDisk()
}

private func loadFromDisk() {
    // Load stops
    if let cached = try? storage.load(forKey: "stops", as: [Stop].self, maxAge: Self.cacheTTL) {
        self.stops = cached
        DebugLog.log("📦 [Cache] Loaded \(cached.count) stops from cache")
    }

    // Load location
    if let cached = try? storage.load(forKey: "location", as: LocationContext.self, maxAge: .infinity) {
        self.currentLocation = cached
        DebugLog.log("📦 [Cache] Loaded location: \(cached.provinceName)")
    }

    // Load line colors
    if let cached = try? storage.load(forKey: "colors", as: [String: String].self, maxAge: Self.cacheTTL) {
        self.lineColorsCache = cached
        DebugLog.log("📦 [Cache] Loaded \(cached.count) line colors from cache")
    }

    // Load platforms
    if let cached = try? storage.load(forKey: "platforms", as: [String: PlatformsCacheData].self, maxAge: Self.cacheTTL) {
        self.platformsDiskCache = cached
        DebugLog.log("📦 [Cache] Loaded platforms for \(cached.count) stations")
    }

    // Load shapes
    if let cached = try? storage.load(forKey: "shapes", as: [String: [ShapePoint]].self, maxAge: .infinity) {
        self.shapeCache = cached
        DebugLog.log("📦 [Cache] Loaded shapes for \(cached.count) routes")
    }
}
```

Note: `PlatformsCacheData` replaces the old `PlatformsCacheEntry` — it's just `[PlatformInfo]` per stop. Or simplify to `[String: [PlatformInfo]]` directly.

- [ ] **Step 4: Replace save calls throughout the file**

Search for every call to the old save functions and replace:

- `saveStopsCache(coordinatesHash: coordHash)` → `try? storage.save(object: stops, forKey: "stops")`
- `saveLinesCache(coordinatesHash: coordHash)` → `try? storage.save(object: lines, forKey: "lines")` + `saveLineColors()`
- `saveLocationCache()` → `try? storage.save(object: currentLocation, forKey: "location")` (check for nil first)
- `savePlatformsCache()` → `try? storage.save(object: platformsDiskCache, forKey: "platforms")`
- `saveShapeCache()` → `shapeCacheQueue.sync { try? storage.save(object: shapeCache, forKey: "shapes") }`

For `saveLineColors()`, create a small helper:
```swift
private func saveLineColors() {
    var colors: [String: String] = lineColorsCache
    for line in lines {
        let name = line.name.lowercased()
        colors[name] = line.colorHex
        colors[line.name] = line.colorHex
        if name.hasPrefix("l") || name.hasPrefix("c") {
            colors[String(name.dropFirst())] = line.colorHex
        }
    }
    lineColorsCache = colors
    try? storage.save(object: colors, forKey: "colors")
}
```

- [ ] **Step 5: Replace loadLinesFromCache in fetchLinesIfNeeded**

In `fetchLinesIfNeeded()`, the current code calls `loadLinesFromCache(coordinatesHash:)`. Replace with:

```swift
if let cached = try? storage.load(forKey: "lines", as: [Line].self, maxAge: Self.cacheTTL) {
    self.lines = cached
    self.linesLoaded = true
    saveLineColors()  // Populate in-memory color lookup
    DebugLog.log("📦 [Cache] Loaded \(cached.count) lines from cache")
    // ... existing verify/return logic
}
```

- [ ] **Step 6: Remove silent verify logic**

Delete `silentVerifyLines()` and any calls to it. Delete `silentVerifyStops()` if it exists. The `shouldVerifyStops()` and `shouldVerifyLines()` checks and their callers should already be deleted from Step 2, but search for any remaining references.

- [ ] **Step 7: Replace clearAllCaches in clearData**

The `clearData()` method (used by developer mode / reset) currently calls `clearAllCaches()`. Replace with:

```swift
try? storage.removeAll()
```

- [ ] **Step 8: Verify no old cache references remain**

Search for these patterns in the iOS DataService and fix any remaining references:
```bash
grep -n "CacheMetadata\|stopsCacheURL\|linesCacheURL\|lineColorsCacheURL\|platformsCacheURL\|shapeCacheURL\|locationCacheURL\|saveLinesCache\|saveStopsCache\|loadCachedData\|shouldVerify\|updateStopsVerify\|updateLinesVerify\|silentVerify\|checkAppVersion\|LineColorsCache\|StopsCache\|LinesCache" "WatchTrans iOS/Services/DataService.swift"
```

Should return 0 matches.

- [ ] **Step 9: Build iOS target**

```bash
xcodebuild -project WatchTrans.xcodeproj -scheme "WatchTrans iOS" -destination "platform=iOS Simulator,name=iPhone 17 Pro" build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: BUILD SUCCEEDED

- [ ] **Step 10: Commit**

```bash
git add "WatchTrans iOS/Services/DataService.swift"
git commit -m "refactor: Replace iOS DataService cache with Storage (~300 lines removed)"
```

---

### Task 3: Replace Watch DataService cache with Storage

**Files:**
- Modify: `WatchTrans Watch App/Services/DataService.swift`

- [ ] **Step 1: Apply same changes as Task 2**

The Watch DataService has the same cache infrastructure. Apply the exact same changes:
1. Add `storage` property and `cacheTTL` constant
2. Delete all old cache structs, metadata, URLs, save/load/verify functions
3. Replace `init()` with `loadFromDisk()`
4. Replace all save calls with `storage.save()`
5. Replace `loadLinesFromCache()` with `storage.load()`
6. Remove silent verify
7. Replace `clearAllCaches()` with `storage.removeAll()`

The Watch DataService is structurally identical to iOS for cache code, so the same patterns apply. Read the file first to confirm line numbers.

- [ ] **Step 2: Verify no old cache references remain**

```bash
grep -n "CacheMetadata\|stopsCacheURL\|linesCacheURL\|lineColorsCacheURL\|platformsCacheURL\|shapeCacheURL\|locationCacheURL\|saveLinesCache\|saveStopsCache\|loadCachedData\|shouldVerify\|updateStopsVerify\|updateLinesVerify\|silentVerify\|checkAppVersion\|LineColorsCache\|StopsCache\|LinesCache" "WatchTrans Watch App/Services/DataService.swift"
```

Should return 0 matches.

- [ ] **Step 3: Commit**

```bash
git add "WatchTrans Watch App/Services/DataService.swift"
git commit -m "refactor: Replace Watch DataService cache with Storage"
```

---

### Task 4: Build and verify

- [ ] **Step 1: Build iOS**

```bash
xcodebuild -project WatchTrans.xcodeproj -scheme "WatchTrans iOS" -destination "platform=iOS Simulator,name=iPhone 17 Pro" build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

- [ ] **Step 2: Fix any compilation errors**

If there are references to deleted types/functions, fix them.

- [ ] **Step 3: Final commit and push**

```bash
git add -A
git commit -m "fix: Resolve any remaining build issues from cache migration"
git push
```
