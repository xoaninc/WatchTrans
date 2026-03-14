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
**Issue:** The RAPTOR engine returns "No journeys found" for all Metro Madrid stations (e.g., Sol `METRO_12` -> Gran Vía `METRO_87`).
**Hypothesis:** The backend has not loaded `stop_times.txt` or transfer data for the Metro Madrid network into the routing engine.
**Verification:** Verified that Cercanías Sevilla (e.g., Dos Hermanas to Santa Justa) routing works correctly.

### Sevilla C4 Route Shape



**Endpoint:** `GET /api/gtfs/stops/{stop_id}/departures`

**Status:** ⚠️ Backend issue detected.

**Issue:** For certain lines/regions (e.g., Metro Sevilla L1), the API returns multiple trip entries for the same departure time and destination, differing only by their `trip_id` (likely due to overlapping active calendars like `INV1-2025` and `INV1-2026`).

**Impact:** The app displays duplicate departure entries for the same train.

**Recommendation:** Backend should de-duplicate these entries on the server-side before sending the response, ensuring only unique, relevant trips are returned.



### Accesos y equipos no expuestos para Metro Madrid y TMB

**Endpoint:** `GET /api/gtfs/stops/{stop_id}/accesses`
**Status:** ❌ Devuelve `[]` para Metro Madrid y TMB Metro Barcelona.

**Issue:** El backend tiene datos de accesos (ROADMAP 3.4: TMB 1,065 pathways, Renfe 195 accesos) pero están en `station-interior`, no en `accesses`. El endpoint `/accesses` devuelve vacío para estas redes. Lo mismo con `/equipment-status` — solo Metro Sevilla tiene datos RT.

**Impacto:** La app tiene `EquipmentStatusSection` genérico listo para cualquier red, pero solo Metro Sevilla lo muestra. Cuando el backend exponga accesos/equipos de Madrid y Barcelona a través de estos endpoints, la app los mostrará automáticamente.

**Acción necesaria en backend:** Migrar los datos de `station-interior` a los endpoints `accesses` y/o `equipment-status`, o crear un endpoint unificado que la app pueda consumir.

---

*Note: All core functionality for Andalusia Metros is now 100% verified.*
