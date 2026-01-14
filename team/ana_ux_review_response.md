# Product Owner Response to UX Review

**Author:** Ana Torres (Product Owner)
**Date:** 2026-01-14
**In Response To:** miguel_ux_review.md

---

## Overall Assessment

Miguel's analysis is solid. The core insight is correct: **we're building a phone app flow for a watch**. Users don't want to navigate, they want to glance.

I'm approving most recommendations with some adjustments for MVP scope.

---

## Decision Matrix

| Recommendation | Decision | Rationale | Release |
|----------------|----------|-----------|---------|
| Start with nearest stop arrivals | **APPROVED** | Core value proposition. No menu on launch. | MVP |
| Watch face complications | **APPROVED** | Essential for watchOS. Without this, users won't engage. | MVP |
| Redesign termometro | **APPROVED** | Use Option A (contextual, collapsed). Full list is v2. | MVP |
| Progress bars for time | **APPROVED** | Better visual hierarchy than text. | MVP |
| Digital Crown scrolling | **APPROVED** | Native watchOS pattern, must use. | MVP |
| Notifications | **DEFERRED** | Important but adds complexity. Need backend support. | v1.1 |
| Long-press favorites | **APPROVED** | Standard iOS pattern, low effort. | MVP |
| Voice search | **DEFERRED** | Nice to have, not critical. | v2.0 |
| Haptic at interchanges | **APPROVED** | Low effort, high delight. | MVP |

---

## Revised MVP Scope

### Must Have (MVP)
1. Auto-detect nearest stop on launch
2. Show next 3-5 arrivals immediately
3. One complication (medium size: line + destination + time)
4. Simplified termometro (contextual, not full list)
5. Favorites (up to 5, not 3)
6. Digital Crown navigation
7. Basic delay indication

### Should Have (v1.1)
1. Push notifications for delays
2. All complication sizes
3. Journey planning (A to B)
4. Full termometro with search

### Could Have (v2.0)
1. Voice search
2. Siri integration
3. Multi-province support
4. Widget for iPhone companion app

---

## Updated User Stories for MVP

### US-001: Instant Arrivals
> As a commuter, I want to see arrivals for my nearest stop immediately when I open the app, so I don't waste time navigating.

**Acceptance Criteria:**
- App opens to arrivals screen in < 1 second
- Location detected automatically
- Shows nearest stop name + distance
- Lists next 5 arrivals with line, destination, and time
- Pull to refresh

### US-002: Quick Favorites
> As a regular user, I want to save my common stops, so I can check them without relying on location.

**Acceptance Criteria:**
- Long-press any stop to add to favorites
- Maximum 5 favorites
- Favorites accessible via swipe from home
- Favorites show distance from current location

### US-003: Watch Face Complication
> As a commuter, I want to see my next train on my watch face, so I don't need to open the app.

**Acceptance Criteria:**
- Medium complication shows: line icon + destination + minutes until arrival
- Updates every 60 seconds
- Tapping complication opens app to that stop

### US-004: Line Explorer
> As a user in a new area, I want to browse available lines and stops, so I can plan my journey.

**Acceptance Criteria:**
- Accessible via "Browse" button (not primary action)
- Grouped by transport type (Metro, Cercanías, Tram)
- Contextual termometro shows: nearest stop highlighted, 2 stops before/after
- Tap stop to see arrivals

### US-005: Delay Visibility
> As a commuter, I want to clearly see if my train is delayed, so I can adjust my plans.

**Acceptance Criteria:**
- Delayed arrivals show warning icon
- Delay shown as "+X min" not crossed-out time
- Visual indicator (color/icon) distinguishes on-time vs delayed

---

## Questions for Team

### For Carlos (iOS Dev):
1. Can we get location on app launch fast enough (< 1 sec)?
2. What's the complexity of complications vs main app?
3. Can Digital Crown scroll a SwiftUI List smoothly?

### For Lucia (Backend):
1. Does NAP provide real-time delay data?
2. What's the refresh rate we can sustain without draining battery?
3. Can we cache line/stop data locally to speed up launch?

### For Miguel (UX):
1. Please create Figma mockups for the 5 user stories above
2. Focus on 45mm Apple Watch first
3. Include complication designs

### For Elena (QA):
1. Start defining test cases for geolocation edge cases
2. Research Apple Watch testing best practices
3. Identify which watch models we need for testing matrix

---

## Timeline Implications

Removing the menu-first approach and adding complications changes our architecture. Carlos should evaluate if this affects estimates.

**Priority order for development:**
1. Core data layer (GTFS parsing, local cache)
2. Home screen with auto-detect arrivals
3. Complication
4. Favorites
5. Line browser with contextual termometro

---

## Open Decisions Needed from Stakeholders

1. **Branding:** Do we use official operator colors/logos or create our own?
2. **Data scope:** Start with Madrid only, or all provinces from day 1?
3. **Monetization:** Free with ads? Paid? Freemium?

---

*Ana Torres - Product Owner*
*"Ship the glance, iterate the features."*
