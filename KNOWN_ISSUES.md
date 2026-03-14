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

## ~~Equipment status de Metro Sevilla: ubicación y estandarización~~ ✅ RESUELTO

Extraído a componente genérico `EquipmentStatusSection.swift` que funciona con cualquier red. Cambios realizados:

- Nombre completo del equipo: "Ascensor — Calle", "Escalera mecanica — Anden sentido Ciudad Expo" (antes solo "Ascensor" truncado)
- Circulo verde/rojo a la derecha de cada equipo indicando estado operativo (antes usaba flechas up/down que indicaban la dirección de la escalera mecánica, dato del campo `direction` del API — no aportaba nada útil al usuario)
- Equipos fuera de servicio aparecen primero, los operativos en un disclosure group
