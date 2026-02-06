# Backend Issues

## Santa Justa (Sevilla) - 500 Internal Server Error

**Endpoint:** `GET /api/gtfs/stops/RENFE_C_51003/correspondences`
**Status:** ❌ 500 Internal Server Error
**Impact:** The "Correspondences" (Transfers) section does not appear for Santa Justa station in the app.
**Hypothesis:** Likely caused by a recursion loop or null pointer exception on the server when calculating connections for this major hub, possibly related to the recent integration of Metro Sevilla L1.

**Workaround:** The app catches the error and hides the section to prevent a crash.

## Metro Sevilla - Empty Departures

**Line:** L1
**Status:** ⚠️ Shapes OK, but real-time departures are empty.
**Impact:** Users can see the line on the map but cannot see train times.
