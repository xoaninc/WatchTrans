# 🔄 Migración a GTFS-RT - Nuevo Servidor

**Fecha:** 2026-02-03  
**Estado:** En progreso

## ✅ Cambios Realizados

### 1. APIConfiguration.swift (iOS + watchOS)
```swift
// ANTES:
static let baseURL = "https://api.watch-trans.app/api/gtfs"

// AHORA:
static let baseURL = "https://api.watch-trans.app/api/gtfs"  // GTFS Estático (sin cambios)
static let gtfsRTBaseURL = "http://localhost:8000/api/gtfs-rt"  // GTFS-RT NUEVO
```

### 2. GTFSRealtimeService.swift (iOS + watchOS)

#### Alerts ✅
- **Antes:** `\(baseURL)/api/gtfs-rt/alerts`
- **Ahora:** `\(baseURL)/api/gtfs-rt/alerts` (Nuevo servidor GTFS-RT)
- **Estado:** Actualizado, funcional

#### Vehicle Positions ⚠️
- **Antes:** `\(baseURL)/realtime/networks/{id}/estimated`
- **Ahora:** `\(gtfsRTBaseURL)/vehicles?operator_id={op}`
- **Estado:** Actualizado, pero retorna array vacío (pendiente mapeo de modelos)

## 🔄 Requisitos Técnicos para Servidor (NUEVO)

Para garantizar la compatibilidad con la App iOS v2.1, el servidor **DEBE** implementar:

### 1. Filtrado Server-Side de Alertas
El cliente ya no descarga todas las alertas. Los endpoints deben soportar query params:
- `GET /api/gtfs-rt/alerts?stop_id={id}`
- `GET /api/gtfs-rt/alerts?route_id={id}`
- **Respuesta:** JSON array `[AlertResponse]` filtrado.

### 2. Route Planner: Camera Hints
Para arreglar el bug visual en mapas 3D, el endpoint de planning debe incluir el heading sugerido.
- **Endpoint:** `GET /api/gtfs/route-planner`
- **Campo requerido:** `segments[].suggested_heading` (Double, 0-360, opcional)
- **Uso:** Indica la orientación de la cámara para seguir ese segmento.

### 3. Vehículos Enriquecidos
El endpoint `/vehicles` debe devolver por defecto (o con `enrich=true`) los campos compatibles con la app antigua para evitar adaptadores.
- **Campos:** `trip_id`, `route_id`, `route_short_name` (obligatorios)

---

## 📝 Formato de Respuesta

### Alerts - NUEVO Formato
```json
{
  "id": "fgc_OBSERVATIONS_F0144_UN_1770126042",
  "operator_id": "fgc",
  "alert_id": "OBSERVATIONS_F0144_UN",
  "header_text": "Últim cotxe reservat escolar",
  "description_text": null,
  "url": null,
  "is_active": true,
  "timestamp": "2026-02-03T14:40:42.792126"
}
```

**⚠️ Incompatibilidades detectadas:**
- ❌ Falta `informedEntities` array en nuevo formato
- ❌ Falta `cause`, `effect`, `activePeriodStart/End`
- ✅ Tiene `operator_id` (nuevo)
- ✅ Tiene `is_active` boolean

### Vehicle Positions - NUEVO Formato
```json
{
  "id": "fgc_vehicle_123",
  "operator_id": "fgc",
  "vehicle_id": "123",
  "latitude": 41.393,
  "longitude": 2.173,
  "bearing": null,
  "speed": null,
  "timestamp": "2026-02-03T14:40:42"
}
```

**⚠️ Incompatibilidades detectadas:**
- ❌ Falta `tripId`, `routeId`, `routeShortName`
- ❌ Falta `currentStopId/Name`, `nextStopId/Name`
- ❌ Falta `progressPercent`, `estimated` flag
- ⚠️ El nuevo servidor requiere `enrich=true` para estos datos

## 🔧 Tareas Pendientes

### Alta Prioridad
- [ ] **Adaptar AlertResponse model** para nuevo formato
  - Opción A: Crear nuevo `GTFSRTAlertResponse` y adaptar
  - Opción B: Modificar `AlertResponse` existente
  - Opción C: Añadir campo `operator_id` + mantener compatibilidad

- [ ] **Implementar mapeo Vehicle Positions**
  - Crear `VehiclePositionResponse` para nuevo formato
  - Crear adapter: `VehiclePositionResponse` → `EstimatedPositionResponse`
  - Requerir `enrich=true` para obtener trip/route info

- [ ] **Servidor: Añadir `informedEntities` a alerts**
  - Parsear `alert_id` para extraer route/stop info
  - Añadir campo compatible con formato antiguo

### Media Prioridad
- [ ] Actualizar `gtfsRTBaseURL` a producción cuando esté deployed
- [ ] Añadir handling de errores para ambos servidores
- [ ] Implementar fallback si nuevo servidor falla
- [ ] Tests de integración

### Baja Prioridad
- [ ] Migrar `/departures` endpoint (sigue funcionando en antiguo)
- [ ] Optimizar cache con TTLs específicos por endpoint
- [ ] Metrics/monitoring de uso de ambos servidores

## 🚀 Deployment

### Desarrollo (Actual)
```swift
static let gtfsRTBaseURL = "http://localhost:8000/api/gtfs-rt"
```

### Producción (Pendiente)
```swift
static let gtfsRTBaseURL = "https://api.watchtrans.com/api/gtfs-rt"
// O usar mismo dominio:
static let gtfsRTBaseURL = "https://api.watch-trans.app/api/gtfs-rt"
```

## 🎯 Próximos Pasos

1. **Hoy:** Adaptar modelos de respuesta (AlertResponse)
2. **Esta semana:** Implementar VehiclePosition mapping
3. **Siguiente:** Deploy a producción + cambiar URLs
4. **Después:** Deprecar endpoints antiguos `/realtime/*`

## 📊 Estado de Operadores

| Operador | Alerts | Vehicles | Trip Updates |
|----------|--------|----------|--------------|
| FGC | ✅ | ⚠️ Pending | ❌ |
| TMB | ⚠️ | ⚠️ Pending | ❌ |
| Bilbao | ⚠️ | ⚠️ Pending | ❌ |
| Euskotren | ⚠️ | ⚠️ Pending | ❌ |

**Leyenda:**
- ✅ Funcionando completamente
- ⚠️ Implementado pero necesita ajustes
- ❌ No implementado

---

## 🐛 Issues Conocidos

1. **AlertResponse incompatible:** Nuevo formato no incluye `informedEntities`
   - **Workaround:** Filtrar todos y hacer matching client-side (ineficiente)
   - **Fix:** Servidor debe añadir campo compatible

2. **VehiclePosition sin enrichment:** Datos básicos sin trip/route info
   - **Workaround:** Usar `?enrich=true` + mapear respuesta
   - **Fix:** Implementar adapter en app

3. **Sin filtro por stop/route en servidor:** Cliente debe filtrar todos los datos
   - **Workaround:** Fetch all + filter client-side
   - **Fix:** Añadir endpoints filtrados en servidor

---

**Último Update:** 2026-02-03 15:03 UTC