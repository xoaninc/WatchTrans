# Backup: TabView Navigation Approach

This folder contains the **alternative navigation approach** using TabView with swipe navigation.

## What's Backed Up

1. **ContentView.swift** - TabView approach with vertical swipe navigation
2. **FavoritesView.swift** - Dedicated favorites page

## Design Approach

Based on **Miguel's UX recommendations** (the UX designer):
- **TabView** with vertical page style
- **Swipe down** to access Favorites view
- **Swipe up** to return to Home
- Star button to add/remove favorites
- Separate page for browsing favorites

## Key Features

- ✅ Vertical swipe navigation (Home ↔ Favorites)
- ✅ Visible star button next to stop name
- ✅ Dedicated Favorites page with list
- ✅ Tap favorite to view arrivals
- ✅ Context menu to remove favorites

## Why It Was Replaced

User requested to follow the **ORIGINAL spec design** instead:
- Main screen with **Favorites section** (top)
- **Recommended section** below (nearest + frequent stops)
- **"Check Lines" button** at bottom
- All on one scrollable page

## How to Restore This Approach

If you want to use this TabView approach again:

1. Copy `ContentView.swift` from this backup folder to the main app folder
2. Make sure `FavoritesView.swift` is in the `Views/` folder
3. Rebuild in Xcode

---

**Date Backed Up:** 2026-01-14
**Commit Reference:** `332722b` (Phase 5 Complete)
