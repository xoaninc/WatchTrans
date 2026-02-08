# Backend Data Coverage & Issues

## Real-time Data Availability
The following networks currently support real-time arrivals/delays in the app:
- ✅ **Renfe Cercanías** (All nucleos)
- ✅ **TMB Metro Barcelona**
- ✅ **Metro Bilbao**
- ✅ **FGC** (Ferrocarrils de la Generalitat de Catalunya)
- ✅ **Euskotren**
- ✅ **Metro Sevilla** (L1) - *Fully verified with live departures*
- ✅ **Metro Granada** - *Fully verified with live departures*
- ✅ **Metro Málaga** (L1+L2) - *Integrated and live*

The following networks are currently **Static Only** (No real-time departures):
- ⚠️ **Metro Madrid** (Shapes/Lines only)
- ⚠️ **Tram Barcelona** (Shapes/Lines only)

## Resolved Issues (2026-02-07)
- ✅ **Santa Justa (Sevilla) 500 error**: Fixed, now returns 200 OK.
- ✅ **Generic Connection Data ("true")**: Replaced with specific line numbers (L1, T1, etc.).
- ✅ **Metro Sevilla Empty Departures**: Fixed, now returning real-time data.
- ✅ **JSONB Correspondences**: Implemented and backwards compatible.
- ✅ **Duplicate Bug**: Resolved.
- ✅ **Expired Calendars**: Resolved (valid until 2026-12-31).

## Unresolved Backend Limitations

### Metro Madrid Route Planner
**Endpoint:** `GET /api/gtfs/route-planner`
**Status:** ❌ PENDIENTE
**Issue:** The RAPTOR engine does not return routes between Metro Madrid stations.
**Example:** Sol -> Gran Vía returns "No route found".

### Sevilla C4 Route Shape
**Status:** ⚠️ Incorrect route path.
**Impact:** The map line for C4 Sevilla appears incorrect (likely straight lines or outdated GTFS data).
**Recommendation:** Update GTFS shapes for Renfe Sevilla C4.

---
*Note: All core functionality for Andalusia Metros is now 100% verified.*