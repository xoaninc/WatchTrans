# Accessibility Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:executing-plans to implement this plan.

**Goal:** Show 3 levels of accessibility info: station badge, per-train indicator, Acerca PMR service.

**Architecture:** Model additions + UI changes in existing views. No new API calls.

**Tech Stack:** Swift, SwiftUI

**Spec:** `docs/superpowers/specs/2026-03-17-accessibility-design.md`

---

## Task 1: Add AcercaService model + StopResponse field

**Files:**
- Modify: `WatchTrans iOS/Services/GTFSRT/WatchTransModels.swift`
- Modify: `WatchTrans iOS/Models/Stop.swift`
- Modify: `WatchTrans iOS/Services/DataService.swift`

- [ ] **Step 1:** Add `AcercaService` struct to WatchTransModels.swift (before StopResponse)
- [ ] **Step 2:** Add `acercaService: AcercaService?` to StopResponse with CodingKey `acerca_service`
- [ ] **Step 3:** Add `let acercaService: AcercaService?` to Stop model, init, and CodingKeys
- [ ] **Step 4:** Pass `acercaService: response.acercaService` in all StopResponse→Stop mappings in DataService
- [ ] **Step 5:** Build and commit

## Task 2: Station ♿ badge + Acerca section in StopDetailView

**Files:**
- Modify: `WatchTrans iOS/Views/Stop/StopDetailView.swift`

- [ ] **Step 1:** Add ♿ badge after Parking badge (wheelchairBoarding == 1 → blue "Accesible", == 2 → red "No accesible")
- [ ] **Step 2:** Remove old `accesibilidad` text display
- [ ] **Step 3:** Add Acerca PMR section below badges when `stop.acercaService` is not nil
- [ ] **Step 4:** Build and commit

## Task 3: Per-train ♿ in ArrivalRowView

**Files:**
- Modify: `WatchTrans iOS/Components/ArrivalRowView.swift`

- [ ] **Step 1:** Add ♿ icon next to destination when `arrival.wheelchairAccessible == true`
- [ ] **Step 2:** Build and commit
