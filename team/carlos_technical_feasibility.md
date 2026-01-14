# Technical Feasibility Assessment

**Author:** Carlos Mendez (iOS/watchOS Developer)
**Date:** 2026-01-14
**In Response To:** miguel_ux_review.md, ana_ux_review_response.md

---

## Summary

Most UX recommendations are technically feasible. Main concerns are: location speed on launch, complication refresh limits, and battery impact of real-time updates.

---

## Feasibility Analysis

### 1. Auto-detect Nearest Stop on Launch

**Feasibility:** ✅ Feasible with caveats

**Technical Details:**
- `CLLocationManager` can provide cached location instantly
- Fresh GPS fix takes 1-3 seconds
- watchOS 10+ has improved background location

**Approach:**
```swift
// Use cached location for instant display
let cachedLocation = locationManager.location

// Show results immediately with cached data
showArrivals(near: cachedLocation)

// Update when fresh location arrives
locationManager.requestLocation() // async update
```

**Risk:** First launch after reboot = no cache = delay

**Mitigation:** Show "Locating..." with spinner, then animate in results

---

### 2. Watch Face Complications

**Feasibility:** ✅ Feasible but with Apple limitations

**Technical Details:**
- Complications update via `TimelineProvider`
- Apple limits updates to ~4 per hour for battery
- Can request more with `WidgetKit` budget

**Complication Types Available:**
| Family | Size | What We Can Show |
|--------|------|------------------|
| `accessoryCircular` | Small | Line icon only |
| `accessoryRectangular` | Medium | Line + Dest + Time ✅ |
| `accessoryInline` | Text | "C3 Aranjuez 5m" |
| `accessoryCorner` | Corner | Line icon + time |

**Approach:**
```swift
struct WatchTransComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "NextArrival",
            provider: ArrivalTimelineProvider()
        ) { entry in
            ArrivalComplicationView(entry: entry)
        }
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}
```

**Risk:** 4 updates/hour may show stale data

**Mitigation:**
- Show "last updated" timestamp
- Tap complication refreshes on app open
- Use `relevantDate` to prioritize updates near arrival times

---

### 3. Contextual Termometro (Collapsed)

**Feasibility:** ✅ Fully Feasible

**Technical Details:**
- SwiftUI `List` with sections
- Collapse/expand with `DisclosureGroup`
- Current stop detection via location matching

**Approach:**
```swift
struct TermometroView: View {
    let stops: [Stop]
    let currentStopIndex: Int

    var body: some View {
        List {
            if currentStopIndex > 2 {
                CollapsedSection(stops: stops[0..<currentStopIndex-2])
            }

            ForEach(visibleStops) { stop in
                StopRow(stop: stop, isCurrent: stop.id == currentStop.id)
            }

            if currentStopIndex < stops.count - 3 {
                CollapsedSection(stops: stops[currentStopIndex+3...])
            }
        }
    }
}
```

**Risk:** None significant

---

### 4. Digital Crown Scrolling

**Feasibility:** ✅ Native behavior, no extra work

**Technical Details:**
- SwiftUI `List` and `ScrollView` support Digital Crown by default
- Can add `.digitalCrownRotation()` for custom behavior
- Haptic feedback via `WKInterfaceDevice.current().play(.click)`

**Approach:**
```swift
ScrollView {
    ForEach(arrivals) { arrival in
        ArrivalRow(arrival: arrival)
    }
}
.focusable(true) // Enables Digital Crown
```

**Bonus:** Add haptic at interchange stops
```swift
.onChange(of: scrollPosition) { newStop in
    if newStop.hasInterchange {
        WKInterfaceDevice.current().play(.notification)
    }
}
```

**Risk:** None

---

### 5. Progress Bars for Time

**Feasibility:** ✅ Fully Feasible

**Technical Details:**
- Simple `ProgressView` or custom `GeometryReader` bar
- Calculate progress: `1 - (remainingTime / totalWaitTime)`

**Approach:**
```swift
struct ArrivalProgressBar: View {
    let arrival: Arrival

    var progress: Double {
        let total = arrival.scheduledTime.timeIntervalSince(arrival.queryTime)
        let remaining = arrival.scheduledTime.timeIntervalSinceNow
        return max(0, min(1, 1 - (remaining / total)))
    }

    var body: some View {
        ProgressView(value: progress)
            .tint(arrival.isDelayed ? .orange : .green)
    }
}
```

**Risk:** None

---

### 6. Push Notifications (Deferred to v1.1)

**Feasibility:** ⚠️ Feasible but requires backend

**Technical Details:**
- Requires APNs (Apple Push Notification service)
- Backend must monitor delays and trigger pushes
- watchOS can receive notifications independently

**Dependencies:**
- Lucia needs to build notification service
- Need to handle notification permissions
- Battery impact of frequent checks

**Recommendation:** Correct to defer. MVP should focus on pull, not push.

---

### 7. Haptic Feedback at Interchanges

**Feasibility:** ✅ Trivial

**Code:**
```swift
WKInterfaceDevice.current().play(.success) // or .notification, .click
```

**Risk:** None

---

### 8. Long-press for Favorites

**Feasibility:** ✅ Native SwiftUI

**Code:**
```swift
StopRow(stop: stop)
    .contextMenu {
        Button("Add to Favorites") {
            favoritesManager.add(stop)
        }
    }
```

**Risk:** None

---

## Architecture Recommendations

### Data Flow
```
NAP API → Lucia's Backend → Local Cache (SwiftData) → UI
                               ↓
                         Complication Timeline
```

### Local Caching Strategy
- **Static data** (lines, stops, connections): Cache indefinitely, update weekly
- **Real-time data** (arrivals): Cache 30 seconds, refresh on scroll/tap
- **User data** (favorites): SwiftData, synced via iCloud

### Recommended Stack
| Component | Technology |
|-----------|------------|
| UI | SwiftUI |
| Local DB | SwiftData (iOS 17+) |
| Networking | URLSession + async/await |
| Location | CoreLocation |
| Complications | WidgetKit |
| Analytics | TelemetryDeck (privacy-first) |

---

## Answers to Ana's Questions

> 1. Can we get location on app launch fast enough (< 1 sec)?

**Yes**, using cached location. Fresh fix adds 1-3 sec but we can show cached results immediately.

> 2. What's the complexity of complications vs main app?

**Medium complexity.** Complications share data model with app but have separate UI and update logic. Estimate: +3 days of work.

> 3. Can Digital Crown scroll a SwiftUI List smoothly?

**Yes**, this is native behavior. No extra work needed.

---

## Questions for Lucia (Backend)

1. What format does NAP provide? GTFS static + GTFS-RT?
2. Can we get a data dump for Madrid to start local development?
3. What's the API rate limit? Do we need our own caching proxy?

---

## Risk Summary

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Slow first launch (no location cache) | Medium | Low | Show loading state gracefully |
| Stale complication data | High | Medium | Show timestamp, refresh on tap |
| NAP API unreliable | Unknown | High | Local cache + graceful degradation |
| Battery drain from location | Medium | Medium | Use significant location change, not continuous |

---

## Estimated Effort (Story Points)

| Feature | Points | Notes |
|---------|--------|-------|
| Project setup & architecture | 3 | SwiftData, networking layer |
| Home screen with arrivals | 5 | Location + API + UI |
| Complication | 5 | TimelineProvider + UI |
| Favorites | 3 | SwiftData + context menu |
| Line browser | 3 | Basic list UI |
| Contextual termometro | 5 | Collapse logic + current detection |
| Polish & edge cases | 3 | Error states, loading, empty states |
| **Total** | **27** | |

---

*Carlos Mendez - iOS/watchOS Developer*
*"Ship the complication first. That's where users live."*
