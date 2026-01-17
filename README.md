# WatchTrans - Spanish Transport Watch App

**Official Repository:** [github.com/xoaninc/App-watch](https://github.com/xoaninc/App-watch)

---

## 🚀 Project Overview

WatchTrans is an Apple Watch (watchOS 11+) application for Spanish public transport. It provides real-time arrival information for metro, trains (Cercanías), and trams using official data from Spain's National Access Point (NAP).

### Core Features

✅ **Home Screen**
- Auto-detects nearest stop on launch
- Shows next 2 arrivals per stop
- Favorites section (max 5 stops)
- Recommended section (nearest + 2 others)
- Pull-to-refresh with haptic feedback

✅ **Watch Face Complication**
- 4 complication types: Rectangular, Circular, Corner, Inline
- Shows line, destination, and time
- Progress bar visualization
- Delay indicators
- Updates every 2.5 minutes

✅ **Line Browser**
- Browse all Metro and Cercanías lines
- Grouped by transport type
- Auto-filters by detected nucleo
- Visual termometro with connections

✅ **Real-Time Data** (COMPLETE)
- Live arrivals with delays
- Train position tracking
- Platform information (with estimated indicator)
- Service alerts
- Frequency-based departures for Metro

✅ **Data Coverage** (COMPLETE)
- **Madrid:** Cercanías + Metro + Metro Ligero
- **Sevilla:** Cercanías
- **Barcelona:** Rodalies
- **Valencia:** Cercanías
- **Málaga:** Cercanías
- **Bilbao:** Cercanías
- **San Sebastián:** Cercanías
- Data loaded dynamically from RenfeServer API

---

## 📱 Screenshots

*Coming soon*

---

## 🛠️ Tech Stack

- **Platform:** watchOS 11+
- **Language:** Swift
- **UI:** SwiftUI
- **Persistence:** SwiftData (favorites)
- **Location:** CoreLocation
- **Complications:** WidgetKit
- **Backend:** RenfeServer API (redcercanias.com)
- **Data Source:** GTFS + GTFS-Realtime processed by backend

---

## 📂 Project Structure

```
watch_transport-main/
├── WatchTransApp/                    # Main Xcode project
│   ├── WatchTrans.xcodeproj
│   └── WatchTrans Watch App/
│       ├── WatchTransApp.swift      # App entry + SwiftData
│       ├── ContentView.swift         # Home screen
│       ├── Models/
│       │   ├── TransportType.swift
│       │   ├── Line.swift
│       │   ├── Stop.swift
│       │   ├── Arrival.swift
│       │   └── Favorite.swift
│       ├── Views/
│       │   ├── ArrivalCard.swift
│       │   ├── LinesView.swift      # Line browser
│       │   └── LineDetailView.swift # Termometro
│       └── Services/
│           ├── LocationService.swift
│           ├── DataService.swift    # ✅ UPDATED with all 39 lines
│           └── FavoritesManager.swift
├── gtfs-extraction/                  # GTFS extraction work
│   ├── scripts/                     # Python extraction scripts
│   ├── swift-complete/              # Complete Swift line definitions
│   ├── data/                        # JSON extraction results
│   └── README.md
├── docs/                             # Documentation
│   ├── INTEGRATION_COMPLETE.md      # Integration summary
│   ├── COMPLETE_EXTRACTION_SUMMARY.md
│   └── [other documentation files]
├── README.md                         # This file
└── PROJECT_STATUS.md
```

---

## 🎯 Development Roadmap

### Phase 1: GTFS Data Extraction ✅ COMPLETE
- [x] Extract all Spanish Cercanías networks
- [x] Organize data in gtfs-extraction folder
- [x] Create Swift line definitions

### Phase 2: RenfeServer API Integration ✅ COMPLETE
- [x] Connect to RenfeServer backend (redcercanias.com)
- [x] Dynamic data loading by nucleo
- [x] Nucleo detection via bounding boxes

### Phase 3: Real-Time Integration ✅ COMPLETE
- [x] Live departures with delays
- [x] Train position tracking
- [x] Service alerts
- [x] Platform information (with estimated indicator)
- [x] Frequency-based departures for Metro
- [x] 60s cache with stale fallback

### Phase 4: Widget & Complications ✅ COMPLETE
- [x] Rectangular complication
- [x] Circular complication
- [x] Corner complication
- [x] Inline complication
- [x] Configurable stop selection

### Phase 5: Polish & App Store ⏳ IN PROGRESS
- [ ] App Group for widget location sharing
- [ ] Retry logic for network errors
- [ ] Offline state UI
- [ ] App Store preparation
- [ ] Screenshots and marketing

---

## 🚦 Current Status

**Last Updated:** January 17, 2026
**Current Phase:** Phase 5 - Polish & App Store
**Backend:** RenfeServer API fully integrated
**Next Task:** App Group implementation for widget

### Recent Achievements ✅
- ✅ Full real-time integration with RenfeServer API
- ✅ Train position tracking and delay display
- ✅ Service alerts system
- ✅ All 4 widget complication types working
- ✅ Platform information with historical estimation
- ✅ Frequency-based departures for Metro

See [docs/INTEGRATION_COMPLETE.md](./docs/INTEGRATION_COMPLETE.md) for detailed integration documentation.

---

## 🔧 Setup Instructions

### Prerequisites
- macOS 14+
- Xcode 16+
- Apple Watch (physical device or simulator)

### Build Steps

1. Clone the repository:
```bash
git clone https://github.com/xoaninc/App-watch.git
cd App-watch
```

2. Open the Xcode project:
```bash
cd WatchTransApp/WatchTrans
open WatchTrans.xcodeproj
```

3. **Configure App Group** (required for widget):

   **WatchTrans Watch App target:**
   - Select target → Signing & Capabilities → + Capability → App Groups
   - Add: `group.juan.WatchTrans`

   **WatchTransWidgetExtension target:**
   - Same steps, add same group: `group.juan.WatchTrans`

4. Select your target Apple Watch device/simulator

5. Build and run (⌘ + R)

### Location Permissions

The app requires location access. Add to `Info.plist`:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>WatchTrans needs your location to find nearby stops</string>
```

---

## 📊 Data Sources

### RenfeServer API (Primary)
- **Base URL:** https://redcercanias.com/api/v1/gtfs
- **Endpoints:**
  - `/nucleos` - All networks with bounding boxes
  - `/stops/by-nucleo` - Stops by network
  - `/routes` - Routes by network
  - `/stops/{id}/departures` - Real-time departures
  - `/realtime/alerts` - Service alerts
  - `/realtime/estimated` - Train positions
- **Update Frequency:** Real-time (30s cache on server)

### Original Data Source
- **Portal:** https://data.renfe.com/dataset
- **GTFS-Realtime:** Processed by RenfeServer
- **License:** Creative Commons Attribution 4.0

---

## 👥 Team

- **Juan Macias Gomez** - Project Owner
- **Claude Sonnet 4.5** - AI Development Assistant

### Fictional Team Members (from design docs)
- Ana Torres - Product Owner
- Carlos Mendez - iOS/watchOS Developer
- Miguel Ruiz - UX/UI Designer
- Lucia Fernandez - Backend Developer
- Elena Garcia - QA Engineer

---

## 📄 License

*To be determined*

---

## 🙏 Acknowledgments

- Spanish Ministry of Transport (MITMA) for NAP data
- Renfe for open GTFS data
- Apple for watchOS and WidgetKit

---

## 📞 Contact

- **GitHub:** [@xoaninc](https://github.com/xoaninc)
- **Repository:** [App-watch](https://github.com/xoaninc/App-watch)

---

**⚠️ IMPORTANT: This is your main working directory**

If you see a folder named `watch_transport-MILESTONE_HomeScreen_Complete` in Downloads, that's an OLD backup from before the complication was added. Always work in `watch_transport-main`.
