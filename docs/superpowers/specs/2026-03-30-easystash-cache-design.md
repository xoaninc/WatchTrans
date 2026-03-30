# Replace Custom Cache with EasyStash Pattern

Date: 2026-03-30

## Problem

DataService has ~300 lines of custom cache code: `CacheMetadata` with timestamps/versions/coordinatesHash, separate save/load functions per data type, silent verify intervals, manual JSON encode/decode. Overly complex for what it does.

## Solution

Replace with a single `Storage` class (~80 lines) based on the EasyStash pattern: save/load Codable objects to disk as JSON files, use filesystem `modificationDate` as timestamp, `maxAge` checked at load time.

## Storage API

```swift
class Storage {
    init(folder: String)
    func save<T: Codable>(object: T, forKey key: String) throws
    func load<T: Codable>(forKey key: String, as type: T.Type, maxAge: TimeInterval) throws -> T
    func remove(forKey key: String) throws
    func removeAll() throws
    func exists(forKey key: String) -> Bool
    func removeExpired(maxAge: TimeInterval) throws
}

enum StorageError: Error {
    case notFound
    case expired
    case decodeFailed
}
```

- Files stored in `cachesDirectory/WatchTransCache/`
- `modificationDate` of the file = when it was saved
- `maxAge` checked at load time: `Date() - modificationDate > maxAge` → throws `.expired`
- Decode failure → throws `.decodeFailed` (model changed, cache is stale)
- No NSCache memory layer — DataService `@Observable` already holds arrays in memory
- No versions, no metadata structs, no verify timestamps

## How DataService Uses It

```swift
private let storage = Storage(folder: "WatchTransCache")

// Load
do {
    stops = try storage.load(forKey: "stops_\(coordHash)", as: [Stop].self, maxAge: 86400)
} catch {
    stops = try await fetchFromAPI()
    try? storage.save(object: stops, forKey: "stops_\(coordHash)")
}
```

## Cache Keys and TTLs

| Cache | Key pattern | maxAge | Notes |
|---|---|---|---|
| Stops | `stops_{coordHash}` | 86400 (24h) | coordHash = "40.45,-3.69" |
| Lines | `lines_{coordHash}` | 86400 (24h) | Same pattern |
| Line colors | `colors_{coordHash}` | 86400 (24h) | `[String: String]` dict |
| Platforms | `platforms_{stopId}` | 86400 (24h) | Per stop |
| Shapes | `shapes_{routeId}` | `.infinity` | Route geometry never changes |
| Location | `location` | `.infinity` | Overwritten on location change |

Location change: new coordHash → different key → automatic cache miss. Old files cleaned by `removeExpired()`.

## What Gets Removed from DataService (~300 lines)

- `CacheMetadata` struct (timestamp, lastVerified, coordinatesHash, version)
- `LineColorsCacheMetadata` struct
- All static `*CacheURL` properties (stopsCacheURL, linesCacheURL, etc.)
- `loadCachedData()` — replaced by individual `storage.load()` calls
- `saveLinesCache()`, `loadLinesFromCache()`
- `shouldVerifyStops()`, `shouldVerifyLines()`
- `silentVerifyLines()`, `silentVerifyStops()`
- `updateStopsVerifyTimestamp()`, `updateLinesVerifyTimestamp()`
- `checkAppVersionAndClearCacheIfNeeded()`
- All `*CacheMetadata` instance properties
- `StopsCache`, `LinesCache`, `LineColorsCache` wrapper structs

## What Stays

- In-memory arrivals cache (20s TTL, different system)
- OfflineScheduleService cache (separate concern)
- SharedStorage for widgets (App Groups)

## Cleanup on Launch

`storage.removeExpired(maxAge: 86400)` at init. Walks the cache folder, deletes files with `modificationDate` > 24h. Excludes shapes (they use `.infinity`).

Implementation: files with `maxAge: .infinity` are saved with a special prefix or in a subfolder, OR `removeExpired` takes a list of prefixes to skip.

Simpler: `removeExpired` checks all files, and shapes are saved with a very large maxAge. Since shapes are re-saved when accessed, their modificationDate stays fresh.

Actually simplest: don't auto-cleanup. The OS purges `cachesDirectory` under storage pressure. Files expire naturally when `load()` fails with `.expired`. Dead files just sit there until the OS cleans them. No cleanup code needed.

## Files

**New (1):**
- `Storage.swift` — copied to both iOS and Watch targets

**Modified (2):**
- `WatchTrans iOS/Services/DataService.swift` — remove ~300 lines, add Storage usage
- `WatchTrans Watch App/Services/DataService.swift` — same

**Not touched:**
- Views, models, OfflineScheduleService, SharedStorage
