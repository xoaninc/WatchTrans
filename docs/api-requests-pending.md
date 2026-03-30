# Campos pendientes de la API para la app

Campos que la app necesita y la API no devuelve aún.

---

## GET /api/gtfs/networks

| Campo | Estado | Para qué lo necesita la app |
|-------|--------|---------------------------|
| `transport_type` | Campo existe en modelo Swift pero API devuelve null | Ya no bloquea la app (las secciones agrupan por `agencyId`), pero serviría para ordenar redes por tipo sin depender del `routeType` de las rutas. |
| `logo` | No existe | URL o filename del logo del operador. Sin este campo la app solo muestra el icono genérico del transportType (MetroSymbol, TrenSymbol, etc.). |
| `name` | Existe pero con nombres legales GTFS | Algunos nombres son ilegibles ("AJUNTAMENT DE BUNYOLA R4", "Consorcio Regional de Transportes de Madrid"). La app los muestra tal cual ahora — si se quieren nombres bonitos, hay que corregirlos en el servidor. |

**Valores esperados de `transport_type`:**

| code | transport_type |
|------|---------------|
| RENFE_C* | `"cercanias"` |
| RENFE_FEVE | `"cercanias"` |
| RENFE_PROX_* | `"cercanias"` |
| SFM_MALLORCA | `"cercanias"` |
| TMB_METRO | `"metro"` |
| METRO_MAD | `"metro"` |
| METRO_SEVILLA | `"metro"` |
| METRO_BILBAO | `"metro"` |
| METROVALENCIA | `"metro"` |
| METRO_MALAGA | `"metro"` |
| METRO_GRANADA | `"metro"` |
| METRO_TENERIFE | `"metro"` |
| METRO_L_MAD | `"metro_ligero"` |
| TUSSAM | `"tram"` |
| TRAM_BCN, TRAM_BCN_BESOS | `"tram"` |
| TRAM_ALICANTE | `"tram"` |
| TRANVIA_ZARAGOZA | `"tram"` |
| TRANVIA_MURCIA | `"tram"` |
| FGC | `"fgc"` |
| EUSKOTREN | `"euskotren"` |

---

## GET /api/gtfs/networks — campo `city` a borrar

`city` siempre es null. La app ya lo borró del modelo. El servidor puede dejar de mandarlo.

---

## Planos (PDFs)

La app ahora construye la URL del plano como `{baseURL}/{type}/{network_code}.pdf`. Para que funcione, los PDFs en el servidor deben seguir esta convención de naming:

| Tipo | Path esperado | Ejemplo |
|------|--------------|---------|
| metro | `metro/{code}.pdf` | `metro/metro_sevilla.pdf` |
| cercanias | `cercanias/{code}.pdf` | `cercanias/renfe_c4.pdf` |
| tranvia | `tranvia/{code}.pdf` | `tranvia/tussam.pdf` |

Actualmente los PDFs en el servidor usan nombres como `metro/sevilla_metro.pdf`, `cercanias/madrid_cercanias.pdf`. Hay que renombrarlos para que matcheen el network code, o añadir un campo `plan_url` a `/networks` para que la app no tenga que adivinar el path.

---

## GET /api/gtfs-rt/alerts — `alternative_transport`

Campo existe en el modelo Swift y la UI está implementada. Pero la API siempre devuelve `null`. Groq extrae la info del texto pero no la expone en el campo. Cuando se popule, la app mostrará automáticamente ruta del bus, frecuencia, estaciones de inicio/fin.

---

## GET /api/gtfs-rt/alerts — `content` + `image_url`

Alertas de noticias de Metro Sevilla. La app solo muestra `headerText`/`descriptionText`. Si estos campos se populan, la app podría mostrar contenido rico e imágenes.

---

## Ya implementado en la API

### `route_type` en stops ✅
- Endpoints: `/stops?search=`, `/stops/by-coordinates`, `/stops/{id}`
- Campo: `route_type: Int?` (0=tram, 1=metro, 2=rail, 3=bus, 7=funicular)
- La app ya lo consume para determinar `TransportType`.

### `wheelchair_accessible` como Int ✅
- Endpoint: `/stops/{id}/departures`
- Campo: `wheelchair_accessible: Int?` (null=sin dato, 1=desconocido, 2=accesible, 3=no accesible)
- La app ya lo consume con prioridad RT → fallback static.

---

## GET /api/gtfs/stops/{id} — campos de capabilities del operador

| Campo | Estado | Para qué lo necesita la app |
|-------|--------|---------------------------|
| `has_occupancy` | No existe | Saber si la parada tiene datos de ocupación en tiempo real. Sin este campo la app hace fetch para todas las paradas y el endpoint devuelve vacío. |
| `has_equipment_status` | No existe | Saber si la parada tiene estado de equipos (ascensores, escaleras). Sin este campo la app hace fetch para todas. |
| `has_air_quality` | No existe | Saber si la parada tiene datos de calidad del aire. Sin este campo la app hace fetch para todas. |

---

## GET /api/gtfs/stops/{id}/departures — route_type

| Campo | Estado | Para qué lo necesita la app |
|-------|--------|---------------------------|
| `route_type` | No existe | Tipo de transporte de la ruta (0=tram, 1=metro, 2=rail). La app lo necesita para decidir formato de hora (>30min). Actualmente lo saca del Line model via `transportType`. |

---

## Normalización de IDs de Renfe en alertas

`AlertFilterHelper` y `DataService` tienen lógica para normalizar IDs de Renfe que vienen en múltiples formatos del feed GTFS-RT de alertas (con/sin prefijo `RENFE_`, formatos legacy). Cuando la API normalice los IDs de alertas en el servidor, esta lógica del cliente se puede eliminar.

Archivos afectados:
- `WatchTrans iOS/Services/AlertFilterHelper.swift`
- `WatchTrans iOS/Services/DataService.swift` (normalizeStopId, fallback por ID legacy)
- `WatchTrans Watch App/Services/DataService.swift` (mismo)

---

## No requiere cambio de API (bugs de la app)

### `corBus` — correspondencia bus sin badges
- El campo `cor_bus` se envía en stops pero la app no muestra badges de correspondencia bus.
- Falta implementar en `StopDetailView` allBadges.

### Pathway modes incompletos
- `/stops/{id}/station-interior` solo devuelve `walkway` y `stairs`.
- La app tiene código defensivo para `escalator`, `elevator`, `moving_sidewalk`, `fare_gate` pero ninguna estación los devuelve.
