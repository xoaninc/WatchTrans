# Known Issues

## ~~StopAlertBadge shows on all Renfe stations~~ ✅ RESUELTO

`StopAlertBadge` se eliminó. Las alertas por parada ahora se filtran usando `AlertFilterHelper.alertsForStop()`, que solo muestra alertas con stop-level entities (entidades con `stop_id` específico). Esto evita que alertas genéricas de ruta aparezcan en todas las paradas. Implementado en iOS y watchOS `LineDetailView`.

Además, alertas `FULL_SUSPENSION` con stop-level entities ahora se tratan como suspensión parcial (no marcan toda la línea como cerrada).

## API field renames not propagated to app models (FIXED)

The backend API renamed several fields but the app models were not updated, causing silent decoding failures:

- **`networks[].code` → `networks[].id`** — `NetworkInfo` in DataService and `NetworkResponse` in WatchTransModels expected `code`, API now returns `id`. Caused lines to not load at all (`keyNotFound` error).
- **`correspondences.cercanias` → `correspondences.tren`** — iOS `StopCorrespondences` still used `cercanias`, Watch App was already updated. Caused train correspondences to silently not decode.

**Fix:** Updated CodingKeys to map the new API field names (commits `6314089`, `e793039`).

**Lesson:** When renaming fields in the backend API, grep the app codebase for all usages of the old field name across both targets.

## Equipment status de Metro Sevilla: ubicación y estandarización

El estado de equipos (ascensores/escaleras mecánicas) de Metro Sevilla aparece mal colocado en la UI y no sigue un patrón estándar que se pueda reutilizar cuando se añadan ascensores/salidas de otras redes.

- La sección de equipos está metida dentro de `StopDetailView` (iOS) de forma ad-hoc para Metro Sevilla
- Cuando se añadan datos de equipos de Metro Madrid, TMB, etc., la implementación actual no escala — hay que diseñar una sección genérica de "estado de equipos" que funcione para cualquier red
- Pendiente definir dónde mostrar esto (sección propia en StopDetailView, o card separada)
- Comparar con cómo lo muestran las apps de Metro de Madrid y Metro de Barcelona para seguir un patrón familiar para el usuario

**Solo iOS** — watchOS no tiene esta funcionalidad implementada.
