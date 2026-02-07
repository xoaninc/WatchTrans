# Backend Data Coverage & Issues

## Real-time Data Availability
The following networks currently support real-time arrivals/delays in the app:
- ✅ **Renfe Cercanías** (All nucleos)
- ✅ **TMB Metro Barcelona**
- ✅ **Metro Bilbao**
- ✅ **FGC** (Ferrocarrils de la Generalitat de Catalunya)
- ✅ **Euskotren**

The following networks are currently **Static Only** (No real-time departures):
- ⚠️ **Metro Sevilla** (Shapes/Lines only)
- ⚠️ **Metro Madrid** (Shapes/Lines only)
- ⚠️ **Metro Granada** (Shapes/Lines only)
- ⚠️ **Tram Barcelona** (Shapes/Lines only)

## Unresolved Backend Limitations

### Metro Madrid Route Planner
**Endpoint:** `GET /api/gtfs/route-planner`
**Status:** ❌ PENDIENTE
**Issue:** The RAPTOR engine does not return routes between Metro Madrid stations.
**Example:** Sol -> Gran Vía returns "No route found".

### Metro Sevilla Departures
**Status:** ⚠️ API returns empty departures array.
**Impact:** Users cannot see waiting times for Metro Sevilla.

---
*Note: All correspondence (500 error) and generic connection ("true") issues were FIXED on 2026-02-07.*