# Campos pendientes de la API para la app

Campos que la app necesita y la API no devuelve aún.

---

## GET /api/gtfs/networks

| Campo | Estado | Para qué lo necesita la app |
|-------|--------|---------------------------|
| `transport_type` | Campo existe en modelo Swift pero API devuelve null | Agrupar líneas por sección (Cercanías/Metro/Tram). Sin este campo, `networkDisplayName(for:)` no funciona y las secciones muestran el fallback genérico. |
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
