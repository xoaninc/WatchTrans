# Cambios 31 Enero 2026

## API (renfeserver)

### Filtro por provincia sin límite de radio
- **Archivo:** `adapters/http/api/gtfs/routers/query_router.py`
- **Cambio:** Cuando `filter_by_province=True`, busca las paradas más cercanas de la provincia del usuario SIN límite de distancia
- **Problema resuelto:** Usuario en zona rural de Sevilla veía paradas de Málaga (más cercanas geográficamente) en lugar de las de su provincia
- **Estado:** Desplegado en producción

### Mapas de Cercanías (12 núcleos)
- **Ruta:** `/static/planos/cercanias/`
- **Archivos añadidos:**
  - `barcelona_cercanias.pdf`
  - `valencia_cercanias.pdf`
  - `bilbao_cercanias.pdf`
  - `san_sebastian_cercanias.pdf`
  - `santander_cercanias.pdf`
  - `asturias_cercanias.pdf`
  - `murcia_alicante_cercanias.pdf`
  - `zaragoza_cercanias.pdf`
  - `cadiz_cercanias.pdf`
  - `sevilla_cercanias.pdf`
- **Ya existían:** `madrid_cercanias.pdf`, `malaga_cercanias.pdf`

---

## iOS App

### Optimización de carga - Prefetch de llegadas
- **Archivo:** `WatchTrans iOS/Views/MainTabView.swift`
- **Cambios:**
  1. Prefetch incluye ahora paradas cercanas (no solo favoritos y frecuentes)
  2. Prefetch es bloqueante (se completa antes de mostrar UI)
- **Flujo nuevo:**
  1. FASE 1: Cargar stops (rápido desde cache)
  2. FASE 2: Prefetch de TODAS las llegadas en paralelo
  3. FASE 3: Mostrar UI (con datos ya en cache)
  4. FASE 4 (background): Verificar GPS
- **Problema resuelto:** 5 segundos de diferencia entre favoritos y cercanas

### Mapeo de planos de Cercanías
- **Archivo:** `WatchTrans iOS/Views/Lines/LinesListView.swift`
- **Función:** `NetworkPlanView.planInfo`
- **Nuevos casos añadidos:**
  ```swift
  case "san sebastián", "san sebastian", "guipúzcoa", "guipuzcoa", "donostia":
      path = "cercanias/san_sebastian_cercanias.pdf"
  case "santander", "cantabria":
      path = "cercanias/santander_cercanias.pdf"
  case "asturias", "oviedo", "gijón", "gijon":
      path = "cercanias/asturias_cercanias.pdf"
  case "murcia", "alicante", "murcia/alicante":
      path = "cercanias/murcia_alicante_cercanias.pdf"
  case "zaragoza", "aragón", "aragon":
      path = "cercanias/zaragoza_cercanias.pdf"
  case "cádiz", "cadiz":
      path = "cercanias/cadiz_cercanias.pdf"
  ```

---

## Resumen de despliegue

| Componente | Acción necesaria |
|------------|------------------|
| API (query_router.py) | ✅ Desplegado y reiniciado |
| PDFs Cercanías | ✅ Subidos a producción |
| iOS App | ⚠️ Requiere recompilar |
