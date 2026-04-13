# API Authentication + New Stop Fields

**Date:** 2026-04-13
**Scope:** Both iOS and watchOS targets

---

## 1. API Authentication

The API now requires `Authorization: Bearer {key}` on all requests.

### Storage

- New file: `APISecrets.swift` (shared by both targets, added to `.gitignore`)
- Contains a single enum:
  ```swift
  enum APISecrets {
      static let apiKey = "wt_app_ios_..."
  }
  ```
- `APIConfiguration.swift` exposes: `static let authHeader = "Bearer \(APISecrets.apiKey)"`

### NetworkService Changes

Both `performFetch<T>` (line 57) and `performFetchData` (line 136) use `session.data(from: url)` without headers. Change to:

```swift
private func authorizedRequest(for url: URL) -> URLRequest {
    var request = URLRequest(url: url)
    request.setValue(APIConfiguration.authHeader, forHTTPHeaderField: "Authorization")
    return request
}
```

Replace all `session.data(from: url)` calls with `session.data(for: authorizedRequest(for: url))`.

Also add the header to `performPostData` (line ~197).

**Files affected (per target):**
- `Services/Network/NetworkService.swift`
- `Services/APIConfiguration.swift`

---

## 2. New Stop Fields

### Model Changes

**Stop.swift** — Replace `hasParking: Bool` with:
- `bicycleParking: Int` (0=unknown, 1=available, 2=confirmed available) — default 0
- `carParking: Int` (0=unknown, 1=available, 2=confirmed available) — default 0
- Add `stopDescription: String?` (mapped from API `description` field, named `stopDescription` to avoid Swift keyword collision)
- `zone_id` — add as comment only (future implementation)

Remove: `hasParking`, `hasBusConnection`, `hasMetroConnection` (derived from cor_* fields, not API booleans)

**CodingKeys:**
- `bicycleParking = "bicycle_parking"`
- `carParking = "car_parking"`
- `stopDescription = "description"`

**StopResponse** (WatchTransModels.swift, line 367):
- Replace `parkingBicis: String?` with `bicycleParking: Int?` and `carParking: Int?`
- Add `stopDescription: String?`
- Update CodingKeys: `bicycle_parking`, `car_parking`, `description`

**StopFullDetailResponse** (WatchTransModels.swift, line 1453):
- Same changes as StopResponse

**BranchStopInfo** (WatchTransModels.swift, line 255):
- Add `bicycleParking: Int?` and `carParking: Int?` (API sends these in route detail stops)

**DataService.swift** — Update mapping (line 255):
```swift
// Before:
hasParking: response.parkingBicis != nil && response.parkingBicis != "0",

// After:
bicycleParking: response.bicycleParking ?? 0,
carParking: response.carParking ?? 0,
stopDescription: response.stopDescription,
```

Remove `hasBusConnection` / `hasMetroConnection` mappings (unused in UI, derivable from cor_* fields).

**Files affected (per target):**
- `Models/Stop.swift`
- `Services/GTFSRT/WatchTransModels.swift`
- `Services/DataService.swift`

---

## 3. UI Changes (iOS)

### Parking Icons — StopDetailView.swift StopHeaderView section (~line 675)

Replace:
```swift
if stop.hasParking {
    Label("Parking Bici", systemImage: "bicycle")
        .font(.caption)
        .foregroundStyle(.green)
}
```

With:
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

### Description Info Button — StopDetailView.swift

Next to the station name in the header, add an info button:
```swift
if let desc = stop.stopDescription, !desc.isEmpty {
    Button {
        showDescription = true
    } label: {
        Image(systemName: "info.circle")
            .foregroundStyle(.secondary)
    }
    .popover(isPresented: $showDescription) {
        Text(desc)
            .padding()
            .presentationCompactAdaptation(.popover)
    }
}
```

Needs `@State private var showDescription = false` in the view.

### Watch UI

- Parking: Show bike/car icons in stop header if available
- Description: Show as `Text` below stop name (no popover on watchOS)

---

## 4. Offline Cache Compatibility

The Stop model is cached to disk. Changing field names requires handling decode failures gracefully. The existing cache has `has_parking` keys. Options:

- **Chosen:** Let the old cache fail to decode, which triggers a re-fetch from API. The cache is only a 24h fallback — safe to invalidate.

---

## 5. Files Changed Summary

| File | iOS | Watch | Change |
|------|-----|-------|--------|
| `APISecrets.swift` (NEW) | ✅ | ✅ | API key constant |
| `APIConfiguration.swift` | ✅ | ✅ | Auth header property |
| `NetworkService.swift` | ✅ | ✅ | Add auth to all requests |
| `Stop.swift` | ✅ | ✅ | New parking/description fields |
| `WatchTransModels.swift` | ✅ | ✅ | StopResponse, StopFullDetail, BranchStopInfo |
| `DataService.swift` | ✅ | ✅ | Update Stop mapping |
| `StopDetailView.swift` | ✅ | ✅ | Parking icons + info button |
| `.gitignore` | ✅ | — | Exclude APISecrets.swift |
