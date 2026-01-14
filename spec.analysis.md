# WatchTrans Specification Analysis

## Overview

This is a specification for an **Apple Watch (watchOS) application** for public transport in Spain, consuming data from the [NAP (National Access Point)](https://nap.transportes.gob.es/Files/List?filterTT=2&showFilterTT=true) of the Ministry of Transport.

---

## Screen Flow Analysis

### Screen 1: Main Menu

| Option | Description | Max Items |
|--------|-------------|-----------|
| **Favorites** | User-saved stops | Up to 3 |
| **Recommended** | Frequent and/or nearby stops with distance (m) | Up to 3 |
| **Others** | Browse all lines | Undefined |

**Observations:**
- "Others???" suggests this option is not fully defined yet
- Need to clarify: How are "frequent" stops determined? (History? Usage count?)
- Need to clarify: What radius for "nearby"?

---

### Screen 2: Line Browser (via "Others")

Shows all metro, train, and tram lines in the user's **province**.

**Hierarchy:**
```
Transport Type / Operator
  └── Lines (if many lines exist)
```

**Observations:**
- Requires geolocation to determine province
- Need to define threshold for "many lines" triggering submenus
- Should consider: What operators are available in NAP? (RENFE, Metro Madrid, FGC, TRAM, etc.)

---

### Screen 3: Line Detail (Stop List)

When selecting a line, displays:

1. **Quick Access Section (3 stops):**
   - 1 nearest stop (with distance in m)
   - 2 frequent stops (with distance in m)

2. **Termometro/Peine (Full Stop List):**
   - Visual linear representation of all stops on the line
   - Each stop shows **connection icons** (logos of other lines passing through)

**Observations:**
- "Termometro" = "Peine" in transport terminology (visual stop sequence)
- Connection icons require mapping between lines and stops
- UI Challenge: Watch screen is small; a long line with many stops needs scrollable UI

---

### Screen 4: Stop Arrivals/Departures

When selecting a stop from the termometro:

**Data Structure:**
```
[Line Icon] + [Destination] + [Arrival Time]
                            + [Original Time] (strikethrough if delayed)
```

**Example:**
```
C3  Aranjuez    14:32
                14:25 (crossed out = 7 min delay)
```

**Observations:**
- Requires real-time data from NAP
- Need to handle: No service, end of service, disruptions
- Should show both arrivals AND departures, or just arrivals?

---

## Technical Requirements Identified

| Requirement | Details |
|-------------|---------|
| **Data Source** | NAP API (transportes.gob.es) |
| **Platform** | watchOS (Apple Watch) |
| **Geolocation** | Required for province detection and distance calculations |
| **Persistence** | Local storage for favorites and usage history |
| **Real-time** | Live arrival/departure times with delay information |

---

## Open Questions / Ambiguities

1. **"Others???"** - Is there a third option planned? What should it be?
2. **Frequency tracking** - How to determine "frequent" stops? Local history?
3. **Province detection** - What if user is on the border? Multiple provinces?
4. **Line logos/icons** - Where do these come from? NAP? Custom assets?
5. **Offline mode** - Should the app work without connectivity?
6. **Notifications** - Should it alert about delays on favorite lines?
7. **Departures** - The spec mentions "llegadas y salidas" but structure only shows arrivals
8. **Update frequency** - How often to refresh real-time data?

---

## NAP Data Availability

Need to verify what data is available from NAP for transport type 2:
- Static data: Lines, stops, connections, schedules
- Real-time data: Delays, cancellations, live positions

---

## Recommended Next Steps

1. Verify NAP API capabilities and data format (GTFS/GTFS-RT?)
2. Define UX/UI mockups for watch screen constraints
3. Clarify open questions with stakeholders
4. Create detailed technical specification
5. Define MVP scope (which features for v1.0?)
