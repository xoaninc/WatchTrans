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

### Renfe Cercanías Real-time Timeouts
**Status:** ❌ TIMEOUT (-1001)
**Impact:** Real-time departures for Renfe stations (Atocha, San Bernardo, etc.) fail to load or take >15 seconds.
**Hypothesis:** The API server is struggling to fetch real-time data from Renfe's upstream provider, causing the entire request to hang.

### Sevilla C4 Route Shape
**Status:** ✅ FIXED (2026-02-07)
**Root Cause:** 
1. **Data Quality Issue:** 1 trip was misclassified as C4 (should be C1) going to Utrera
2. **Shape Issue:** Original shape only covered 5-stop pattern, not the 6-stop circular route

**Solution Applied:**
- ✅ Reclassified mismatched trip from C4 → C1 (now 0 C4 trips to Utrera)
- ✅ Created new circular shape (`RENFE_C_30_C4_CIRCULAR`) with 76 points
- ✅ Updated 218 circular trips to use correct shape
- ✅ Verified C4 stops no longer include Utrera

**Current State:**
- C4 now shows only 5 correct stops: Santa Justa, Palacio Congresos, Padre Pío-Palmete, Virgen Rocío, San Bernardo
- Two shapes coexist: RENFE_C_30_C4 (494 short trips) and RENFE_C_30_C4_CIRCULAR (218 circular trips)

---
*Note: All correspondence (500 error) and generic connection ("true") issues were FIXED on 2026-02-07.*