# Stop-Level Service Alerts UI — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show station-level alerts (accessibility issues, service disruptions, closures) in StopDetailView, LineDetailView stop rows, and HomeView stop cards.

**Architecture:** The API endpoint `GET /api/gtfs-rt/alerts?stop_id={id}&active_only=true` already resolves route-based alerts for a stop. `DataService.fetchAlertsForStop()` already exists. We add: (1) a lightweight `StopAlertBadge` component for compact views, (2) alert-aware stop rows in LineDetailView, (3) alert badges in HomeView stop cards. StopDetailView already shows alerts via `AlertsSectionView`.

**Tech Stack:** SwiftUI, existing `AlertResponse` model, existing `DataService` alert methods.

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `WatchTrans iOS/Components/StopAlertBadge.swift` | Compact alert badge (dot + optional short text) |
| Modify | `WatchTrans iOS/Views/Lines/LineDetailView.swift` | Add alert fetching per stop, pass to `LineStopRowView` |
| Modify | `WatchTrans iOS/Views/Home/HomeView.swift` | Add alert badge to `StopCardView` and `FrequentStopCardView` |

**Not modified:** `StopDetailView.swift` — already shows alerts via `AlertsSectionView`.

---

## Chunk 1: StopAlertBadge Component

### Task 1: Create StopAlertBadge view

**Files:**
- Create: `WatchTrans iOS/Components/StopAlertBadge.swift`

- [ ] **Step 1: Create the StopAlertBadge component**

This component has two modes:
- **Dot mode** (for HomeView): Just a colored circle overlay
- **Inline mode** (for LineDetailView): Icon + short text

```swift
import SwiftUI

struct StopAlertBadge: View {
    let alerts: [AlertResponse]
    let mode: DisplayMode

    enum DisplayMode {
        case dot      // Small colored dot (HomeView)
        case inline   // Icon + short text (LineDetailView)
    }

    private var topAlert: AlertResponse? {
        // Priority: NO_SERVICE > ACCESSIBILITY_ISSUE > MODIFIED_SERVICE > SIGNIFICANT_DELAYS > REDUCED_SERVICE
        let priority = ["NO_SERVICE", "ACCESSIBILITY_ISSUE", "MODIFIED_SERVICE", "SIGNIFICANT_DELAYS", "REDUCED_SERVICE"]
        return alerts.min { a, b in
            let aIdx = priority.firstIndex(of: a.effect ?? "") ?? priority.count
            let bIdx = priority.firstIndex(of: b.effect ?? "") ?? priority.count
            return aIdx < bIdx
        }
    }

    private var alertColor: Color {
        switch topAlert?.effect {
        case "NO_SERVICE": return .red
        case "ACCESSIBILITY_ISSUE", "SIGNIFICANT_DELAYS": return .orange
        case "MODIFIED_SERVICE", "REDUCED_SERVICE": return .yellow
        default: return .orange
        }
    }

    private var alertIcon: String {
        switch topAlert?.effect {
        case "NO_SERVICE": return "xmark.circle.fill"
        case "ACCESSIBILITY_ISSUE": return "figure.roll"
        case "MODIFIED_SERVICE": return "exclamationmark.triangle.fill"
        case "SIGNIFICANT_DELAYS": return "clock.badge.exclamationmark"
        case "REDUCED_SERVICE": return "arrow.down.circle"
        default: return "exclamationmark.triangle.fill"
        }
    }

    private var shortText: String {
        guard let alert = topAlert else { return "" }
        // Use header_text truncated, or a default by effect
        if let header = alert.headerText, header.count <= 40 {
            return header
        }
        switch alert.effect {
        case "NO_SERVICE": return "Servicio suspendido"
        case "ACCESSIBILITY_ISSUE": return "Accesibilidad reducida"
        case "MODIFIED_SERVICE": return "Servicio modificado"
        case "SIGNIFICANT_DELAYS": return "Retrasos significativos"
        case "REDUCED_SERVICE": return "Frecuencia reducida"
        default: return "Alerta activa"
        }
    }

    var body: some View {
        if alerts.isEmpty { EmptyView() }
        else {
            switch mode {
            case .dot:
                Circle()
                    .fill(alertColor)
                    .frame(width: 8, height: 8)
            case .inline:
                HStack(spacing: 4) {
                    Image(systemName: alertIcon)
                        .font(.caption2)
                        .foregroundStyle(alertColor)
                    Text(shortText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Add preview**

Add a `#Preview` block at the bottom with sample alerts for both modes.

- [ ] **Step 3: Commit**

```bash
git add "WatchTrans iOS/Components/StopAlertBadge.swift"
git commit -m "feat: add StopAlertBadge component for compact alert display"
```

---

## Chunk 2: LineDetailView — Alert-Aware Stop Rows

### Task 2: Add per-stop alert fetching to LineDetailView

**Files:**
- Modify: `WatchTrans iOS/Views/Lines/LineDetailView.swift`

The approach: fetch alerts for all stops in one batch when line data loads, store in a dictionary `[String: [AlertResponse]]`, pass relevant alerts to each `LineStopRowView`.

- [ ] **Step 1: Add state for stop alerts**

Add to the state variables section (~line 17-25):
```swift
@State private var stopAlerts: [String: [AlertResponse]] = [:]
```

- [ ] **Step 2: Fetch alerts for each stop after stops load**

In `loadData()`, after `stops = await dataService.fetchStopsForRoute(...)` succeeds (~line 206), add:

```swift
// Fetch alerts for all stops in parallel
await withTaskGroup(of: (String, [AlertResponse]).self) { group in
    for stop in stops {
        group.addTask {
            let alerts = await dataService.fetchAlertsForStop(stopId: stop.id)
            return (stop.id, alerts)
        }
    }
    for await (stopId, alerts) in group {
        stopAlerts[stopId] = alerts
    }
}
```

**Note:** This makes N parallel requests. If performance is a concern, limit to first 10 stops or add a debounce. But since the API is fast and stops are typically <50, this should be fine.

- [ ] **Step 3: Pass alerts to LineStopRowView**

In the `ForEach` that renders stops (~line 153-173), add alerts parameter to `LineStopRowView`:

Change from:
```swift
LineStopRowView(
    stop: stop,
    lineColor: lineColor,
    isFirst: index == 0,
    isLast: index == stops.count - 1,
    isCircular: line.isCircular,
    dataService: dataService
)
```

To:
```swift
LineStopRowView(
    stop: stop,
    lineColor: lineColor,
    isFirst: index == 0,
    isLast: index == stops.count - 1,
    isCircular: line.isCircular,
    dataService: dataService,
    alerts: stopAlerts[stop.id] ?? []
)
```

- [ ] **Step 4: Update LineStopRowView to accept and display alerts**

In the `LineStopRowView` struct (~line 494+):

Add parameter:
```swift
let alerts: [AlertResponse]
```

Add default value in any existing init or call sites:
```swift
alerts: [AlertResponse] = []
```

In the view body, after the stop name text, add:
```swift
if !alerts.isEmpty {
    StopAlertBadge(alerts: alerts, mode: .inline)
}
```

- [ ] **Step 5: Update preview LineStopRowView calls**

Update any `#Preview` or preview `LineStopRowView(...)` calls to include `alerts: []`.

- [ ] **Step 6: Commit**

```bash
git add "WatchTrans iOS/Views/Lines/LineDetailView.swift"
git commit -m "feat: show per-stop alerts in line detail stop list"
```

---

## Chunk 3: HomeView — Alert Badges on Stop Cards

### Task 3: Add alert badges to HomeView stop cards

**Files:**
- Modify: `WatchTrans iOS/Views/Home/HomeView.swift`

The approach: fetch alerts for favorite and nearby stops when they load, store in a shared dictionary, overlay a dot badge on stop cards that have active alerts.

- [ ] **Step 1: Add state for stop alerts in HomeView or parent**

Find the main HomeView struct and add:
```swift
@State private var stopAlerts: [String: [AlertResponse]] = [:]
```

- [ ] **Step 2: Add alert fetching after stops load**

After favorite stops and nearby stops are loaded, fetch alerts for all of them:

```swift
private func fetchStopAlerts(for stops: [Stop]) async {
    await withTaskGroup(of: (String, [AlertResponse]).self) { group in
        for stop in stops {
            group.addTask {
                let alerts = await dataService.fetchAlertsForStop(stopId: stop.id)
                return (stop.id, alerts)
            }
        }
        for await (stopId, alerts) in group {
            if !alerts.isEmpty {
                stopAlerts[stopId] = alerts
            }
        }
    }
}
```

Call this after stops load in the appropriate `.task` or data loading method.

- [ ] **Step 3: Add dot badge to StopCardView**

In `StopCardView` (~line 519+), add an `alerts` parameter:
```swift
let alerts: [AlertResponse]
```

In the view body, overlay the badge on the stop name or card:
```swift
HStack {
    Text(stop.name)
    if !alerts.isEmpty {
        StopAlertBadge(alerts: alerts, mode: .dot)
    }
}
```

- [ ] **Step 4: Pass alerts from HomeView to StopCardView**

Update all `StopCardView(...)` call sites in HomeView to pass:
```swift
alerts: stopAlerts[stop.id] ?? []
```

- [ ] **Step 5: Do the same for FrequentStopCardView**

Add `alerts` parameter and dot badge, same pattern as StopCardView.

- [ ] **Step 6: Commit**

```bash
git add "WatchTrans iOS/Views/Home/HomeView.swift"
git commit -m "feat: show alert badges on home stop cards"
```

---

## Summary

| Where | What shows | Data source |
|-------|-----------|-------------|
| **StopDetailView** | Full alert section (already exists) | `dataService.fetchAlertsForStop()` |
| **LineDetailView** stop rows | Icon + short text inline | Per-stop alerts fetched in batch |
| **HomeView** stop cards | Colored dot badge | Per-stop alerts fetched after stops load |
