# Known Issues

## StopAlertBadge shows on all Renfe stations

The `StopAlertBadge` component was intended to show accessibility issues but was implemented as a generic alert badge that displays any alert type (suspensions, delays, modified service, etc.). Since all Renfe stations share the same generic alerts, the orange dot appears on every station and adds no value — it's just visual noise.

**Affected views:**
- `HomeView` — dot mode (`.dot`) on nearby and favorite stop cards (3 sections)
- `LineDetailView` — inline mode (`.inline`) with icon + text next to each stop

Each view maintains its own `@State var stopAlerts` and `fetchStopAlerts()`, making individual API calls per stop.

**Options:**
- Limit to accessibility-only alerts (`ACCESSIBILITY_ISSUE` effect)
- Remove it entirely
- Filter out alerts that are shared across all stops in the same network
