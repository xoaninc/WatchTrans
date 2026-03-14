# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

WatchTrans is a real-time Spanish public transport app for iOS and Apple Watch, showing schedules for Cercanías, Metro, Metro Ligero, and Tram networks. It consumes a GTFS/GTFS-RT backend API at `api.watch-trans.app`.

## Build & Development

- **Xcode required**, targeting **iOS 17.0+ / watchOS 10.0+**
- Open project: `open WatchTrans.xcodeproj`
- Build/run: select iOS or Watch target in Xcode and press Run
- Run tests: `Cmd + U` in Xcode (select appropriate target)
- Local API testing: uncomment dev URLs in `APIConfiguration.swift`
- Dependencies are vendored in `Vendor/` (Kingfisher, Pulse, Sentry) — no SPM/CocoaPods

## Architecture

**MVVM + Observable Services** using Swift 6 `@Observable` macro.

### Dual-Target Pattern (Critical)

iOS and watchOS targets have **parallel but separate** file structures. Models and services are duplicated, not shared via a framework. **When changing shared logic (models, services), update both targets.**

```
WatchTrans iOS/          # iOS app
WatchTrans Watch App/    # watchOS app (parallel structure)
WatchTransWidget/        # watchOS widget
atchTransWidgetiOSExtension/  # iOS widget (note: typo in directory name is intentional)
```

### Data Flow

- **Services** (`DataService`, `GTFSRealtimeService`, `NetworkService`) are `@Observable` classes injected into the SwiftUI environment
- **DataService** orchestrates all data with a layered caching strategy:
  - Stops/Lines: 24h disk cache with background silent verification
  - Arrivals: no persistent cache, 45s auto-refresh, 20s in-memory TTL
  - Route shapes: persistent disk cache
- **NetworkService** handles HTTP with exponential backoff retry (max 3 attempts)
- Route calculation happens server-side, not in the client
- **`makeStopDisplays`** creates ONE display per stop using `stop.transportType` (from ID prefix). `cor_*` fields are correspondences (walking connections), NOT lines at the stop.

### Key Services

| Service | Purpose |
|---------|---------|
| `DataService` | Main data orchestrator, caching, state management |
| `GTFSRealtimeService` | GTFS-RT API calls (departures, alerts, vehicle positions) |
| `NetworkService` | HTTP client with retry logic |
| `FavoritesManager` | SwiftData-backed favorites (max 3) |
| `iCloudSyncService` | iCloud KVStore sync for favorites |
| `TrainLiveActivityWidget` | Live Activity widget for in-journey tracking |

### API Configuration

Centralized in `APIConfiguration.swift` per target. Base URLs:
- GTFS Static: `https://api.watch-trans.app/api/gtfs`
- GTFS-RT: `https://api.watch-trans.app/api/gtfs-rt`

Key endpoints documented in `API_STATUS.md`.

### Stop Fields

- `cor_metro`, `cor_tren`, `cor_tranvia`, `cor_funicular` — **correspondences** (walking connections to other stops), NOT lines at the stop. Used for badges only.
- `lineas` field is **removed** — do not use. The server no longer sends it.
- `transportType` is determined from stop ID prefix only (e.g., `METRO_SEVILLA_*` → `.metro`, `RENFE_C_*` → `.cercanias`).

### Synthetic RT Trips

Some operators (Metro Sevilla, Tranvía Zaragoza, TMB Metro) generate synthetic RT trip IDs:
- Prefixes: `MSEV_RT_`, `ZGZ_RT_`, `TMB_METRO_`
- These do NOT exist in `/trips/` endpoint — skip the fetch
- For journey display, use route stops as fallback (`/routes/{route_id}/stops`)
- Double composition in Metro Sevilla: detected by comma in trip_id (e.g., `MSEV_RT_111,116_d0`)

### Alert Filtering

When an alert has both route-level and stop-level entities, only show it for stops explicitly listed in stop-level entities. Route-level-only alerts show for all stops on the route.

## Coding Conventions

- Swift API Design Guidelines: `camelCase` vars/funcs, `PascalCase` types/protocols
- Max 120 characters per line
- SwiftUI state: `@State` for local, `@Observable` for service models
- Prefer `VStack`/`HStack`/`ZStack` over `GeometryReader`
- Document public APIs with `///` comments
- Custom icons (elevator, escalator) use AIGA SVG imagesets with `.renderingMode(.template)` for tinting

## Commit Prefixes

`Add:`, `Fix:`, `Update:`, `Refactor:`, `Docs:`, `Style:`, `Test:`

Recent commits also use conventional format: `fix(scope):`, `feat(scope):`, `perf:`, `docs:`

## Important Rules

- **NEVER hardcode workarounds for API inconsistencies** without asking the user first. The user also maintains the backend — if the API sends unexpected field names or formats, ask before adding fallback logic in the app. The fix likely belongs on the server side.
- **All URLs and API constants go in `APIConfiguration.swift`** — no hardcoded URLs in views, services, or widgets.
- **Commit and push after every functional change** — never accumulate uncommitted work. Each feature, fix, or meaningful change gets its own commit + push immediately.
- **SF Symbols**: verify symbols exist with `NSImage(systemSymbolName:)` before using. `elevator`, `elevator.fill`, `escalator`, `escalator.fill` do NOT exist. Use custom AIGA imagesets instead.

## Key Context

- UI text is in **Spanish**; code (variables, comments) is in **English**
- SwiftData is used only for `Favorite` model persistence
- App Groups (`group.juan.WatchTrans`) enable data sharing between app and widget extensions
- Background refresh task ID: `juan.WatchTrans.refreshDepartures`
- Sentry SDK is vendored but not integrated (imports and initialization removed, Vendor/Sentry kept for future use)
- Metro Sevilla features (iOS only): equipment status, air quality, vehicle composition (Simple/Doble)
- Station occupancy (iOS only): TMB Metro L1-L5, L11
