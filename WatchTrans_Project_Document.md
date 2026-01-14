# WatchTrans - Project Document

**Version:** 1.0
**Date:** 2026-01-14
**Status:** Planning Phase

---

# Table of Contents

1. [Project Overview](#1-project-overview)
2. [Original Requirements](#2-original-requirements)
3. [Requirements Analysis](#3-requirements-analysis)
4. [UX Review & Recommendations](#4-ux-review--recommendations)
5. [Product Decisions](#5-product-decisions)
6. [Technical Feasibility](#6-technical-feasibility)
7. [MVP Definition](#7-mvp-definition)
8. [User Stories](#8-user-stories)
9. [Architecture](#9-architecture)
10. [Team](#10-team)
11. [Open Questions](#11-open-questions)
12. [Next Steps](#12-next-steps)

---

# 1. Project Overview

## What is WatchTrans?

WatchTrans is an **Apple Watch (watchOS) application** for public transport in Spain. It provides real-time arrival information for metro, train (Cercanías), and tram services.

## Data Source

[NAP - National Access Point](https://nap.transportes.gob.es/Files/List?filterTT=2&showFilterTT=true) from the Spanish Ministry of Transport (MITMA).

## Core Value Proposition

> See your next train in a glance. No navigation, no menus, just information.

---

# 2. Original Requirements

*Source: spec.md*

### Screen 1: Main Selection
- Favorites (up to 3 stops)
- Recommended (up to 3 frequent/nearby stops with distance in meters)
- Others (undefined)

### Screen 2: Line Browser (via "Others")
- Shows all metro, train, and tram lines in user's province
- If many lines exist, grouped in submenu by transport type/operator

### Screen 3: Line Detail
- 3 stops: 1 nearest + 2 frequent (with distances)
- Termometro/Peine: Visual list of all stops with connection icons (logos of lines passing through each stop)

### Screen 4: Arrivals
- Structure: Line Icon + Destination + Arrival Time
- If delayed: Original time shown crossed out

---

# 3. Requirements Analysis

## Screen Flow (Original)

```
Main Menu → Others → Transport Type → Line → Termometro → Stop → Arrivals
```

**Problem identified:** 5-6 taps to reach arrival information.

## Ambiguities in Original Spec

| Item | Question | Status |
|------|----------|--------|
| "Others???" | Third option undefined | Resolved: Renamed to "Browse" |
| Frequency tracking | How to determine "frequent" stops? | Decision: Local usage history |
| Province detection | What if user is on border? | Decision: Show all nearby, regardless of province |
| Line logos/icons | Source? | Decision: Custom assets based on official colors |
| Offline mode | Required? | Decision: Deferred to v1.1 |
| Notifications | Alert on delays? | Decision: Deferred to v1.1 |
| Arrivals vs Departures | Show both? | Decision: Show arrivals only for MVP |
| Update frequency | How often refresh? | Decision: 30 seconds, on-demand refresh |

## Technical Requirements

| Requirement | Details |
|-------------|---------|
| **Platform** | watchOS 10+ |
| **Data Source** | NAP API (GTFS/GTFS-RT) |
| **Geolocation** | CoreLocation for proximity detection |
| **Persistence** | SwiftData for favorites and history |
| **Real-time** | Live arrival times with delay indication |
| **Complications** | WidgetKit for watch face integration |

---

# 4. UX Review & Recommendations

*Author: Miguel Ruiz (UX/UI Designer)*

## Critical Issues with Original Spec

### Issue 1: Too Many Taps
- Original: 5+ taps to see arrivals
- Watch expectation: 1-2 taps maximum
- **Solution:** Show arrivals immediately on launch

### Issue 2: Menu-First Design
- Original: Starts with menu selection
- Watch pattern: Start with content, menus secondary
- **Solution:** Auto-detect nearest stop, show arrivals instantly

### Issue 3: Termometro Doesn't Fit
- A line with 30 stops doesn't fit on 45mm screen
- Endless scrolling is frustrating on watch
- **Solution:** Contextual termometro (collapsed sections)

### Issue 4: Delay Display
- Crossed-out time is hard to read on small screen
- No visual hierarchy for urgency
- **Solution:** Progress bars + "+X min delay" format

### Issue 5: Missing Complications
- Watch users live on the watch face
- Not including complications = major miss
- **Solution:** Complications are MVP requirement

## Revised Screen Flow

```
Open App → Nearest Stop Arrivals (instant)
         → Swipe: Alternatives / Favorites
         → Tap: Details / Browse
```

## Recommended Interactions

| Action | Gesture |
|--------|---------|
| Scroll arrivals | Digital Crown |
| Change stop | Swipe left/right |
| Go back | Swipe from edge |
| Refresh data | Pull down |
| Add to favorites | Long press |
| Set arrival alert | Tap arrival → Set reminder |

## Arrival Card Design

**Before (Original):**
```
C3  Aranjuez    14:32
                14:25 (crossed out)
```

**After (Recommended):**
```
┌─────────────────────────┐
│  C3 → Aranjuez          │
│  ███████░░░  2 min      │  ← Progress bar
│  +7 min delay     ⚠️    │  ← Clear delay indication
└─────────────────────────┘
```

## Contextual Termometro Design

```
┌─────────────────────────┐
│  C3 Cercanías           │
│  ─────────────────────  │
│     ↑ 5 previous stops  │  ← Collapsed
│  ●  Sol ← YOU ARE HERE  │  ← Highlighted
│  ○──Atocha [C1][C4]     │  ← Shows connections
│  ○  Recoletos           │
│     ↓ 18 more stops     │  ← Collapsed
└─────────────────────────┘
```

## Complication Designs

| Type | Size | Content |
|------|------|---------|
| Inline | Text | "C3 Aranjuez 5m" |
| Circular | Small | Line icon only |
| Rectangular | Medium | Line + Destination + Time + Progress |
| Corner | Small | Line icon + minutes |

**Primary complication (Rectangular):**
```
┌──────────────────┐
│ 🚆 C3 → Aranjuez │
│ ████░░░░  5 min  │
└──────────────────┘
```

---

# 5. Product Decisions

*Author: Ana Torres (Product Owner)*

## Feature Prioritization

| Feature | Priority | Release | Rationale |
|---------|----------|---------|-----------|
| Auto-detect nearest stop | P0 | MVP | Core value proposition |
| Show arrivals on launch | P0 | MVP | No menu needed |
| Watch face complication | P0 | MVP | Essential for watchOS |
| Contextual termometro | P0 | MVP | Full list won't work |
| Digital Crown scrolling | P0 | MVP | Native pattern |
| Progress bars for time | P1 | MVP | Better than text |
| Favorites (5 stops) | P1 | MVP | Quick access |
| Long-press to favorite | P1 | MVP | Standard pattern |
| Haptic at interchanges | P2 | MVP | Low effort, high delight |
| Delay indicators | P1 | MVP | Core functionality |
| Push notifications | P1 | v1.1 | Requires backend |
| Offline mode | P2 | v1.1 | Cache complexity |
| Journey planning (A→B) | P2 | v1.1 | Scope creep for MVP |
| Full termometro + search | P2 | v1.1 | Nice to have |
| Voice search | P3 | v2.0 | Low priority |
| Siri integration | P3 | v2.0 | Low priority |
| Multi-province | P2 | v2.0 | Start with one region |

## Release Roadmap

### MVP (v1.0)
- Auto-detect nearest stop on launch
- Show next 5 arrivals immediately
- One complication (rectangular)
- Simplified termometro (contextual)
- Favorites (up to 5)
- Digital Crown navigation
- Delay indication with progress bars
- Haptic feedback at interchanges

### Version 1.1
- Push notifications for delays
- All complication sizes
- Offline mode (cached schedules)
- Full termometro with search

### Version 2.0
- Journey planning (A to B)
- Voice search
- Siri Shortcuts integration
- Multi-province support
- iPhone companion app

---

# 6. Technical Feasibility

*Author: Carlos Mendez (iOS/watchOS Developer)*

## Feasibility Summary

| Feature | Feasibility | Notes |
|---------|-------------|-------|
| Auto-detect location | ✅ Feasible | Use cached location for instant display |
| Complications | ✅ Feasible | Apple limits updates to ~4/hour |
| Contextual termometro | ✅ Feasible | SwiftUI DisclosureGroup |
| Digital Crown | ✅ Native | Zero extra work |
| Progress bars | ✅ Trivial | SwiftUI ProgressView |
| Haptic feedback | ✅ Trivial | One line of code |
| Long-press menu | ✅ Native | SwiftUI contextMenu |
| Push notifications | ⚠️ Deferred | Requires backend infrastructure |

## Location Strategy

```swift
// Instant display with cached location
let cachedLocation = locationManager.location
showArrivals(near: cachedLocation) // Immediate

// Background refresh with fresh location
locationManager.requestLocation() // Async update
```

**First launch risk:** No cache = 1-3 second delay
**Mitigation:** Show "Locating..." spinner gracefully

## Complication Limitations

- Apple limits complication updates to ~4 per hour
- Can request more budget but battery impact
- Tapping complication refreshes data in app

**Mitigation:**
- Show "updated X min ago" timestamp
- Prioritize updates near scheduled arrival times
- Full refresh when user opens app

## Recommended Tech Stack

| Component | Technology |
|-----------|------------|
| UI Framework | SwiftUI |
| Local Database | SwiftData (iOS 17+) |
| Networking | URLSession + async/await |
| Location | CoreLocation |
| Complications | WidgetKit |
| Analytics | TelemetryDeck (privacy-first) |

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Slow first launch | Medium | Low | Graceful loading state |
| Stale complication | High | Medium | Timestamp + tap to refresh |
| NAP API unreliable | Unknown | High | Local cache + graceful degradation |
| Battery drain | Medium | Medium | Use significant location changes only |

## Effort Estimation

| Feature | Story Points |
|---------|--------------|
| Project setup & architecture | 3 |
| Home screen with arrivals | 5 |
| Complication | 5 |
| Favorites | 3 |
| Line browser | 3 |
| Contextual termometro | 5 |
| Polish & edge cases | 3 |
| **Total MVP** | **27 points** |

---

# 7. MVP Definition

## In Scope

1. **Smart Home Screen**
   - Auto-detect nearest stop
   - Show next 5 arrivals immediately
   - Pull to refresh
   - Distance to stop in meters

2. **Watch Face Complication**
   - Rectangular complication
   - Shows: Line + Destination + Minutes
   - Tap to open app

3. **Favorites**
   - Save up to 5 stops
   - Long-press any stop to add
   - Swipe to access from home

4. **Line Browser**
   - Grouped by transport type
   - Metro, Cercanías, Tram
   - Madrid region only (MVP)

5. **Contextual Termometro**
   - Shows current stop highlighted
   - 2 stops before/after visible
   - Collapsed sections for rest
   - Connection icons at interchanges

6. **Arrival Display**
   - Line icon with official colors
   - Destination name
   - Progress bar with minutes
   - Delay indicator (+X min)

7. **Interactions**
   - Digital Crown scrolling
   - Haptic feedback at interchanges
   - Swipe navigation

## Out of Scope (MVP)

- Push notifications
- Offline mode
- Journey planning
- Voice/Siri
- iPhone companion app
- Provinces outside Madrid
- Departures (arrivals only)

---

# 8. User Stories

## US-001: Instant Arrivals

> As a commuter, I want to see arrivals for my nearest stop immediately when I open the app, so I don't waste time navigating.

**Acceptance Criteria:**
- [ ] App opens to arrivals screen in < 2 seconds
- [ ] Location detected automatically (cached or fresh)
- [ ] Shows nearest stop name + distance in meters
- [ ] Lists next 5 arrivals with line, destination, and time
- [ ] Pull down to refresh data
- [ ] Loading state shown while fetching

---

## US-002: Watch Face Complication

> As a commuter, I want to see my next train on my watch face, so I don't need to open the app.

**Acceptance Criteria:**
- [ ] Rectangular complication available
- [ ] Shows: line icon + destination + minutes until arrival
- [ ] Updates at least every 15 minutes
- [ ] Tapping opens app to that stop
- [ ] Graceful display when no data available

---

## US-003: Quick Favorites

> As a regular user, I want to save my common stops, so I can check them without relying on location.

**Acceptance Criteria:**
- [ ] Long-press any stop to add to favorites
- [ ] Maximum 5 favorites supported
- [ ] Favorites accessible via swipe from home
- [ ] Each favorite shows distance from current location
- [ ] Can remove favorites via long-press menu

---

## US-004: Line Explorer

> As a user in a new area, I want to browse available lines and stops, so I can plan my journey.

**Acceptance Criteria:**
- [ ] Accessible via "Browse" button on home screen
- [ ] Grouped by transport type (Metro, Cercanías, Tram)
- [ ] Tapping line shows contextual termometro
- [ ] Current/nearest stop highlighted in termometro
- [ ] Tap any stop to see its arrivals

---

## US-005: Delay Visibility

> As a commuter, I want to clearly see if my train is delayed, so I can adjust my plans.

**Acceptance Criteria:**
- [ ] Delayed arrivals show warning icon (⚠️)
- [ ] Delay shown as "+X min" text
- [ ] Progress bar color changes (green → orange) for delays
- [ ] On-time arrivals show no delay indicator

---

## US-006: Interchange Awareness

> As a user viewing the termometro, I want to see which lines connect at each stop, so I can plan transfers.

**Acceptance Criteria:**
- [ ] Interchange stops show connection icons
- [ ] Icons use official line colors
- [ ] Haptic feedback when scrolling past interchange
- [ ] Tapping interchange shows all lines at that stop

---

# 9. Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────┐
│                    APPLE WATCH                          │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │   Main App  │  │ Complication│  │  Favorites  │     │
│  │  (SwiftUI)  │  │ (WidgetKit) │  │ (SwiftData) │     │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘     │
│         │                │                │             │
│         └────────────────┼────────────────┘             │
│                          │                              │
│                ┌─────────▼─────────┐                    │
│                │   Data Manager    │                    │
│                │  (Cache + Fetch)  │                    │
│                └─────────┬─────────┘                    │
└──────────────────────────┼──────────────────────────────┘
                           │
                           ▼
              ┌────────────────────────┐
              │   Backend / Proxy      │
              │   (Optional for MVP)   │
              └────────────┬───────────┘
                           │
                           ▼
              ┌────────────────────────┐
              │      NAP API           │
              │  (GTFS / GTFS-RT)      │
              └────────────────────────┘
```

## Data Model

```swift
// Core entities
struct Line {
    let id: String
    let name: String          // "C3", "L1", "ML1"
    let type: TransportType   // .metro, .cercanias, .tram
    let color: Color
    let stops: [Stop]
}

struct Stop {
    let id: String
    let name: String          // "Sol", "Atocha"
    let location: CLLocation
    let connections: [Line]   // Other lines at this stop
}

struct Arrival {
    let line: Line
    let destination: String   // "Aranjuez"
    let scheduledTime: Date
    let expectedTime: Date    // May differ if delayed
    let platform: String?

    var isDelayed: Bool { expectedTime > scheduledTime }
    var delayMinutes: Int { ... }
}

// User data
struct Favorite {
    let stop: Stop
    let addedDate: Date
    let usageCount: Int
}
```

## Local Caching Strategy

| Data Type | Cache Duration | Storage |
|-----------|----------------|---------|
| Lines & Stops | 7 days | SwiftData |
| Connections | 7 days | SwiftData |
| Real-time arrivals | 30 seconds | Memory |
| Favorites | Permanent | SwiftData + iCloud |
| Usage history | 30 days | SwiftData |

## API Integration

**Expected NAP format:** GTFS (static) + GTFS-RT (real-time)

```
Static data (GTFS):
- routes.txt → Lines
- stops.txt → Stops
- stop_times.txt → Schedules
- transfers.txt → Connections

Real-time data (GTFS-RT):
- TripUpdate → Delays, cancellations
- VehiclePosition → Live locations (if available)
- Alert → Service disruptions
```

---

# 10. Team

## Team Members

| Name | Role | Focus |
|------|------|-------|
| **Ana Torres** | Product Owner | Requirements, backlog, stakeholders |
| **Carlos Mendez** | iOS/watchOS Developer | SwiftUI, WatchKit, architecture |
| **Lucia Fernandez** | Backend Developer | NAP API, GTFS, data services |
| **Miguel Ruiz** | UX/UI Designer | Watch UI, mockups, accessibility |
| **Elena Garcia** | QA Engineer | Testing, TestFlight, quality |

## Contact

| Name | Email | Slack |
|------|-------|-------|
| Ana Torres | ana.torres@watchtrans.dev | @ana_po |
| Carlos Mendez | carlos.mendez@watchtrans.dev | @carlos_ios |
| Lucia Fernandez | lucia.fernandez@watchtrans.dev | @lucia_backend |
| Miguel Ruiz | miguel.ruiz@watchtrans.dev | @miguel_ux |
| Elena Garcia | elena.garcia@watchtrans.dev | @elena_qa |

## Current Assignments

| Team Member | Current Task |
|-------------|--------------|
| Ana | Clarify open questions, finalize MVP scope |
| Carlos | Set up watchOS project, prototype home screen |
| Lucia | Investigate NAP API, download GTFS sample data |
| Miguel | Create Figma mockups for MVP screens |
| Elena | Define test device matrix, write test cases |

---

# 11. Open Questions

## Requiring Stakeholder Decision

| # | Question | Options | Decision |
|---|----------|---------|----------|
| 1 | **Branding** - Use official operator logos? | A) Official logos, B) Custom icons with official colors | Pending |
| 2 | **Geographic scope** - Start with Madrid only? | A) Madrid only MVP, B) All provinces day 1 | Pending |
| 3 | **Monetization** - Business model? | A) Free, B) Paid, C) Freemium with ads | Pending |

## Technical Questions (For Lucia)

| # | Question | Status |
|---|----------|--------|
| 1 | Does NAP provide GTFS-RT real-time data? | Investigating |
| 2 | What operators are available in NAP? | Investigating |
| 3 | API rate limits? | Investigating |
| 4 | Data freshness/update frequency? | Investigating |

## Design Questions (For Miguel)

| # | Question | Status |
|---|----------|--------|
| 1 | What watch sizes to prioritize? | 45mm primary, 41mm secondary |
| 2 | Color palette for transport types? | In progress |
| 3 | Icon style for lines? | In progress |

---

# 12. Next Steps

## Immediate Actions

| # | Action | Owner | Status |
|---|--------|-------|--------|
| 1 | Investigate NAP API capabilities | Lucia | Not started |
| 2 | Download GTFS sample data for Madrid | Lucia | Not started |
| 3 | Create Figma mockups for 5 user stories | Miguel | Not started |
| 4 | Set up Xcode project with SwiftUI | Carlos | Not started |
| 5 | Define test device matrix | Elena | Not started |
| 6 | Get stakeholder decisions on open questions | Ana | Not started |

## Development Priority Order

1. **Core data layer** - GTFS parsing, local cache (SwiftData)
2. **Home screen** - Auto-detect arrivals
3. **Complication** - Watch face integration
4. **Favorites** - SwiftData + context menu
5. **Line browser** - Basic list UI
6. **Contextual termometro** - Collapse logic
7. **Polish** - Error states, loading, empty states

## Success Metrics (MVP)

| Metric | Target |
|--------|--------|
| App launch to arrivals | < 2 seconds |
| Complication update frequency | Every 15 minutes |
| Crash-free sessions | > 99% |
| App Store rating | > 4.0 stars |

---

# Appendix A: Glossary

| Term | Definition |
|------|------------|
| **NAP** | National Access Point - Spanish government transport data portal |
| **GTFS** | General Transit Feed Specification - standard format for transit data |
| **GTFS-RT** | GTFS Realtime - extension for real-time updates |
| **Termometro** | Visual representation of stops along a line (also called "Peine" in RENFE) |
| **Peine** | "Comb" in Spanish - RENFE's term for the linear stop diagram |
| **Cercanías** | RENFE's commuter rail service |
| **Complication** | Small widget on Apple Watch face |

---

# Appendix B: Reference Links

- [NAP Portal](https://nap.transportes.gob.es/Files/List?filterTT=2&showFilterTT=true)
- [GTFS Specification](https://gtfs.org/)
- [watchOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/watchos)
- [WidgetKit Documentation](https://developer.apple.com/documentation/widgetkit)

---

*Document generated: 2026-01-14*
*Last updated by: WatchTrans Team*
