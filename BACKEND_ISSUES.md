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

## Route Stops - Missing Correspondences

**Endpoint:** `GET /routes/{id}/stops`
**Status:** ⚠️ Missing `cor_metro`, `cor_cercanias`, etc. fields for some new stations (e.g. Sevilla).
**Impact:** The "Line Detail" view does not show connection badges for stops because the static stop data lacks this information, even if the dynamic `/stops/{id}/correspondences` endpoint has it.
**Recommendation:** Update the route stops endpoint to populate correspondence fields from the same source as the correspondences endpoint.

## Generic Connection Data ("true" vs Line Numbers)

**Endpoint:** `/routes/{id}/stops` and `/stops/by-coordinates`
**Status:** ⚠️ For new networks (Sevilla, Bilbao), the `cor_` fields (e.g. `cor_tranvia`) return the string `"true"` instead of a list of lines (e.g. `"T1"`).
**Impact:** The app displays generic badges like "TRAM" or "Metro" instead of specific lines like "T1" or "L1".
**Recommendation:** Backend should return the comma-separated list of connecting lines (e.g. "T1") instead of a boolean string.
