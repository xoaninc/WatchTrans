# Xcode Project Setup Instructions

After creating the files, you need to **add them to your Xcode project** and configure some settings.

## Step 1: Add Files to Xcode Project

1. Open `WatchTrans.xcodeproj` in Xcode
2. In the Project Navigator (left sidebar), right-click on "WatchTrans Watch App"
3. Select **"Add Files to 'WatchTrans Watch App'..."**
4. Navigate to and add these folders:
   - `Models/` (select all .swift files inside)
   - `Views/` (select all .swift files inside)
   - `Services/` (select all .swift files inside)
5. Make sure **"Copy items if needed"** is checked
6. Click **"Add"**

## Step 2: Configure Location Permissions

1. In Xcode, select the **WatchTrans** project in the navigator
2. Select the **WatchTrans Watch App** target
3. Go to the **Info** tab
4. Click the **+** button to add a new key
5. Add these keys:

   | Key | Type | Value |
   |-----|------|-------|
   | `Privacy - Location When In Use Usage Description` | String | `WatchTrans needs your location to find nearby transport stops` |

## Step 3: Build and Run

1. Select a watchOS Simulator or your paired Apple Watch
2. Press **⌘ + R** to build and run
3. Grant location permissions when prompted
4. You should see the home screen with mock arrivals!

## Files Created

### Models
- `TransportType.swift` - Transport type enum (metro, cercanías, tram)
- `Line.swift` - Line model with stops
- `Stop.swift` - Stop model with location
- `Arrival.swift` - Arrival model with delay calculation
- `Favorite.swift` - SwiftData model for favorites

### Views
- `ArrivalCard.swift` - Arrival display component
- `ContentView.swift` - Main home screen (updated)

### Services
- `LocationService.swift` - Location detection and nearest stop finder
- `DataService.swift` - Data fetching (currently with mock data)

## Current Features

- ✅ Auto-detect nearest stop
- ✅ Display arrivals with progress bars
- ✅ Delay indicators
- ✅ Pull to refresh
- ✅ SwiftData configured for favorites
- ✅ Mock data for testing

## Next Steps

1. Test the app in the simulator
2. Verify location permissions work
3. Check that arrivals display correctly
4. Later: Integrate real NAP API data
5. Later: Add favorites functionality
6. Later: Add watch face complications

## Troubleshooting

**If files don't appear in Xcode:**
- Make sure you added them through "Add Files to..." in Xcode
- Check that target membership is set to "WatchTrans Watch App"

**If location doesn't work:**
- In Simulator: Features → Location → Custom Location (enter coordinates)
- On Device: Make sure Watch has permission in iPhone's Watch app

**If build fails:**
- Clean build folder: Product → Clean Build Folder (⇧⌘K)
- Restart Xcode
