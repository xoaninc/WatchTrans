# UX Review - WatchTrans Spec

**Author:** Miguel Ruiz (UX/UI Designer)
**Date:** 2026-01-14
**Document Reviewed:** spec.md

---

## Executive Summary

The current spec has a solid foundation but needs refinement for watchOS constraints. The main issues are: too many taps to reach critical information, unclear hierarchy, and a termometro design that won't work well on a 45mm screen.

---

## Current Flow Analysis

```
Main Menu → Others → Line List → Line Detail (Termometro) → Stop → Arrivals
```

**Problem:** 5 taps minimum to see arrival times. On a watch, users expect information in 1-2 taps maximum.

---

## UX Issues Identified

### 1. Main Menu Structure

**Current:**
- Favorites (3)
- Recommended (3)
- Others???

**Issues:**
- "Others???" is vague and uninviting
- 3 favorites is too limiting
- No clear primary action

**Recommendation:**
```
[Nearby]     ← Primary action, one tap to arrivals
[Favorites]  ← Quick access, swipe for more
[Browse]     ← Full line explorer
```

### 2. Too Many Steps to Information

**Current flow for new user:**
1. Open app
2. Tap "Others"
3. Find transport type
4. Find line
5. Scroll termometro
6. Tap stop
7. Finally see arrivals

**Recommended flow:**
1. Open app → Immediately show nearest stop arrivals
2. Scroll down for alternatives
3. Tap to expand/change

### 3. Termometro/Peine Design

**Problem:** A linear list of 15-30 stops doesn't fit on a 45mm watch screen. Users will scroll endlessly.

**Recommendations:**

**Option A - Contextual Termometro:**
```
     ← Previous stops (collapsed, tap to expand)
  ●  Current/Nearest stop (highlighted)
  ○  Next stop
  ○  Next stop
     → More stops (collapsed)
```

**Option B - Search + Quick Access:**
- Show only: Origin, Current, Key interchanges, Terminus
- Add search/filter for specific stops

**Option C - Digital Crown Navigation:**
- Use Digital Crown to scroll through stops
- Haptic feedback at interchanges
- Current position always centered

### 4. Stop Arrivals Screen

**Current structure:**
```
[Icon] [Destination] [Time]
                     [Delayed time crossed]
```

**Issues:**
- No visual hierarchy for urgency
- Delay information is secondary when it should be primary
- No indication of "leaving now" vs "10 min away"

**Recommended structure:**
```
┌─────────────────────────┐
│  C3 → Aranjuez          │
│  ███████░░░  2 min      │  ← Progress bar showing time
│  Platform 3             │
└─────────────────────────┘

┌─────────────────────────┐
│  C4 → Parla        ⚠️   │  ← Warning icon for delay
│  ██░░░░░░░░  8 min      │
│  +3 min delay           │  ← Delay as addition, not strikethrough
└─────────────────────────┘
```

### 5. Missing: Complications

**Critical for watchOS:** The spec doesn't mention watch face complications.

**Recommended complications:**
- **Small:** Next arrival time for favorite stop
- **Medium:** Line icon + destination + time
- **Large:** Next 2-3 arrivals

This lets users see info WITHOUT opening the app.

### 6. Missing: Notifications

**Should include:**
- "Train arriving in 2 min" for tracked journeys
- Delay alerts for favorited lines
- Service disruption warnings

---

## Revised Screen Flow Proposal

### Screen 1: Smart Home (No menu needed)

```
┌─────────────────────────┐
│  Sol                    │  ← Nearest stop auto-detected
│  ─────────────────────  │
│  C3 Aranjuez    2 min   │
│  C4 Parla       5 min   │
│  L1 Valdecarros 3 min   │
│  ─────────────────────  │
│  [★ Favorites] [Browse] │
└─────────────────────────┘
```

**Swipe left:** Next nearest stop
**Swipe right:** Favorites
**Digital Crown:** Scroll arrivals
**Tap arrival:** Journey details + set reminder

### Screen 2: Favorites (Swipe or tap)

```
┌─────────────────────────┐
│  ★ Favorites            │
│  ─────────────────────  │
│  Atocha         1.2 km  │
│  Sol            200 m   │
│  Nuevos Min.    800 m   │
│  ─────────────────────  │
│  [+ Add favorite]       │
└─────────────────────────┘
```

### Screen 3: Browse (Only when needed)

```
┌─────────────────────────┐
│  Browse Lines           │
│  ─────────────────────  │
│  🚇 Metro Madrid    12  │
│  🚆 Cercanías        8  │
│  🚊 Metro Ligero     3  │
│  ─────────────────────  │
│  [Search by name...]    │
└─────────────────────────┘
```

### Screen 4: Line View (Simplified Termometro)

```
┌─────────────────────────┐
│  C3 Cercanías           │
│  ─────────────────────  │
│     Aranjuez (term)     │
│  ●  Sol ← YOU           │
│  ○──Atocha [C1][C4]     │  ← Interchange indicators
│  ○  Recoletos           │
│     +18 more stops ↓    │
└─────────────────────────┘
```

**Digital Crown:** Smooth scroll through all stops
**Tap stop:** Show arrivals for that stop

---

## Interaction Patterns

| Action | Gesture |
|--------|---------|
| Scroll arrivals | Digital Crown |
| Change stop | Swipe left/right |
| Go back | Swipe from edge / tap back |
| Refresh data | Pull down |
| Add to favorites | Long press on stop |
| Set arrival alert | Tap arrival → Set reminder |

---

## Accessibility Considerations

1. **VoiceOver:** All elements must have descriptive labels
   - "C3 to Aranjuez, arriving in 2 minutes"
   - "Sol station, 200 meters away, 5 connections available"

2. **Dynamic Type:** Support larger text sizes, hide secondary info if needed

3. **Reduce Motion:** Provide static alternatives to animations

4. **High Contrast:** Ensure line colors meet WCAG contrast ratios

---

## Summary of Recommendations

| Priority | Recommendation |
|----------|----------------|
| **P0** | Start with nearest stop arrivals, not a menu |
| **P0** | Add watch face complications |
| **P1** | Redesign termometro for small screens |
| **P1** | Use progress bars instead of crossed-out times |
| **P1** | Digital Crown for scrolling |
| **P2** | Add arrival notifications |
| **P2** | Long-press for quick actions |
| **P3** | Voice search for stops |

---

## Next Steps

1. Create Figma prototypes for revised flow
2. Test with 41mm and 45mm watch simulators
3. User testing with 5 commuters
4. Iterate based on feedback

---

*Miguel Ruiz - UX/UI Designer*
*"On a watch, every tap costs 2 seconds. Design for glances, not sessions."*
