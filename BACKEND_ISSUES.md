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



### Datos de equipos RT solo disponibles para Metro Sevilla

**Endpoint:** `GET /api/gtfs-rt/equipment-status/{stop_id}`
**Status:** ℹ️ Funciona correctamente, solo Metro Sevilla tiene fuente de datos (TCE).

**Situación:**
- `equipment-status` → Solo Metro Sevilla tiene datos RT de ascensores/escaleras (fuente: TCE). Funciona correctamente.
- `accesses` → Devuelve `[]` para Metro Sevilla porque no hay datos GTFS de accesos importados (la web de Metro Sevilla no publica esta info). Correcto.
- `station-interior` → Tiene pathways para TMB (1,065) y Renfe (195), pero son recorridos internos, no equipos RT. Son datos distintos.

**No hay acción necesaria en backend.** Cuando otras redes tengan fuente de datos RT de equipos (como el TCE de Metro Sevilla), el endpoint `equipment-status` los expondrá y la app los mostrará automáticamente con `EquipmentStatusSection`.

---

*Note: All core functionality for Andalusia Metros is now 100% verified.*
