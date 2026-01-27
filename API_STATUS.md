# WatchTrans API Status

**Base URL:** `https://redcercanias.com/api/v1/gtfs`

**Última verificación:** 27 Enero 2026

> **Nota:** Bugs y mejoras pendientes están en `ROADMAP.md`

---

## Endpoints Utilizados

### Datos de Transporte
| Endpoint | Método | Estado | Descripción |
|----------|--------|--------|-------------|
| `/transport?lat={lat}&lon={lon}` | GET | ✅ | Datos de transporte por ubicación |
| `/stops/{stop_id}/departures` | GET | ✅ | Próximas salidas de una parada |
| `/routes/{route_id}/stops` | GET | ✅ | Paradas de una línea |
| `/routes/{route_id}/shape` | GET | ✅ | Recorrido de una línea (polyline) |
| `/routes/{route_id}/shape?max_gap=50` | GET | ✅ | Shape normalizado (servidor interpola) |
| `/stops?search={query}` | GET | ✅ | Búsqueda de paradas |

### Route Planner (RAPTOR)
| Endpoint | Método | Estado | Descripción |
|----------|--------|--------|-------------|
| `/route-planner?from=X&to=Y` | GET | ✅ | Planificador de rutas RAPTOR |

**Parámetros:**
- `from` (string, requerido): ID parada origen
- `to` (string, requerido): ID parada destino
- `departure_time` (string, default: hora actual): Formato HH:MM
- `max_transfers` (int, default: 3): Máximo transbordos (0-5)
- `max_alternatives` (int, default: 3): Alternativas Pareto (1-5)

**Response incluye:** `journeys[]`, `departure`, `arrival`, `suggested_heading`, `alerts[]`

### Plataformas y Correspondencias
| Endpoint | Método | Estado | Descripción |
|----------|--------|--------|-------------|
| `/stops/{stop_id}/platforms` | GET | ✅ | Ubicación de andenes |
| `/stops/{stop_id}/correspondences` | GET | ✅ | Estaciones cercanas a pie |

### Alertas y Tiempo Real
| Endpoint | Método | Estado | Descripción |
|----------|--------|--------|-------------|
| `/realtime/alerts` | GET | ✅ | Alertas activas |
| `/realtime/stops/{stop_id}/alerts` | GET | ✅ | Alertas de una parada |

---

## Estado de Shapes por Red

| Red | Rutas con Shapes | Puntos | Estado |
|-----|------------------|--------|--------|
| Metro Madrid | 121 | ✅ | OK |
| TMB Metro BCN | 11 | ✅ | OK |
| Renfe Cercanías | 63 | ✅ | OK |
| FGC | 20 | ✅ | OK |
| TRAM Barcelona | 55 | ✅ | OK |
| Euskotren | 13 | ✅ | OK |
| Metro Bilbao | L1, L2 | ✅ | OK |
| Metro Ligero | 4 | ✅ | OK |
| SFM Mallorca | 4 | ✅ | OK |
| Metro Sevilla | L1 | 272 | ⚠️ Sin departures |
| Metro Granada | L1 | ✅ | OK (143,098 stop_times) |

**Total:** ~293,638 puntos de shapes

**Nota:** Shapes normalizados disponibles con `?max_gap=50` (servidor interpola)

---

## Estado de Correspondencias Barcelona

### Funcionando ✅
| Estación | Stop ID | Correspondencias |
|----------|---------|------------------|
| Catalunya | `TMB_METRO_1.126` | 3 (L3, FGC, Rodalies) |
| Sants | `RENFE_71801` | 2 (Metro L3, L5) |
| La Sagrera | `TMB_METRO_1.526` | 3 (L1, L5, Rodalies) |
| Clot | `RENFE_79009` | 2 |
| Espanya | `FGC_PE4` | ✅ L1, L3, FGC (arreglado 27/01) |
| Diagonal L3 | `TMB_METRO_1.328` | ✅ L5, FGC Provença |
| Diagonal L5 | `TMB_METRO_1.521` | ✅ L3, FGC Provença |

---

## Estado de Plataformas

| Estación | Stop ID | Platforms | Estado |
|----------|---------|-----------|--------|
| Catalunya | `TMB_METRO_1.126` | 2 (L1, L3) | ✅ |
| Sants | `RENFE_71801` | 1 | ✅ |
| Torrassa | `TMB_METRO_1.117` | ✅ | OK |

---

## Funcionalidades Implementadas en la App

### StopDetailView
- [x] Indicador de conexión Bus (`hasBusConnection`)
- [x] Provincia de la estación (`province`)
- [x] Sección "Estaciones cercanas a pie" (correspondences)
- [x] Sección "Andenes" (platforms)
- [x] Indicadores de Metro, Parking, Accesibilidad

### LineDetailView
- [x] Mapa con recorrido de la línea (shapes)
- [x] Lista de paradas con conexiones
- [x] Horarios de funcionamiento
- [x] Alertas activas

### JourneyPlannerView
- [x] Búsqueda origen/destino
- [x] Cálculo de rutas (Dijkstra)
- [x] Visualización 3D del viaje
- [x] Filtrado por provincia/red

### Journey3DAnimationView (Animación 3D)

Sistema de animación de marcador sobre rutas usando técnicas de Mapbox/Google Maps.

**Arquitectura:**
```
Segmento de ruta (coordinates)
    ↓
normalizeRoute() - Subdivide segmentos >50m
    ↓
sphericalInterpolate() - Interpolación esférica (Slerp)
    ↓
CADisplayLink (60fps) - Sincronizado con pantalla
    ↓
coordinateAlong(distance) - Posición exacta en la línea
    ↓
MapCamera update - Actualiza marcador y cámara
```

**Componentes clave:**

| Componente | Descripción |
|------------|-------------|
| `AnimationController` | Clase que gestiona CADisplayLink y cálculos |
| `normalizeRoute()` | Subdivide puntos muy separados (máx 50m) |
| `sphericalInterpolate()` | Interpolación esférica para precisión geográfica |
| `coordinateAlong()` | Obtiene punto a X km de la línea (como `turf.along`) |
| `calculateHeading()` | Calcula rumbo entre 2 puntos para orientar cámara |

**Configuración:**
- Velocidad base: `0.08 km/s` × multiplicador por modo de transporte
- Frame rate: 60 FPS (CADisplayLink), actualiza cada 2 frames (30fps efectivo)
- Distancia máxima entre puntos: 50m (normalización)
- Pausa entre segmentos: 1.0s
- Suavizado de heading: factor 0.03 (muy suave para evitar vibración)

**Velocidades por modo de transporte:**

| Modo | Vel. Real | Multiplicador | Animación | Tiempo/km |
|------|-----------|---------------|-----------|-----------|
| Metro | ~30 km/h | 1.0× | 0.08 km/s | ~12.5s |
| Cercanías | ~45 km/h | 1.5× | 0.12 km/s | ~8.3s |
| Metro Ligero | ~22 km/h | 0.75× | 0.06 km/s | ~16.7s |
| Tranvía | ~18 km/h | 0.6× | 0.048 km/s | ~20.8s |
| Andando | ~4.5 km/h | 0.15× | 0.012 km/s | ~83s |

**Logs de debug (ejemplo):**
```
▶️ [Segment 1/2] L1 | Olivar → Cartuja | 47 pts
🎬 [Animation] 47→156 pts | 5.23 km | ~65.4s
✅ [Animation] COMPLETE after 3920 frames, 65.3s
🏁 [Journey] ALL SEGMENTS COMPLETE
```

---

## Changelog

### 27 Enero 2026
- **Route Planner RAPTOR** desplegado y funcionando
- **Shapes normalizados** con parámetro `?max_gap=50`
- **Metro Granada** añadido (143,098 stop_times, departures funcionando)
- **Bug C10 arreglado** (ya no incluye Zaragoza)
- **Correspondencias BCN arregladas**: Espanya, Diagonal
- **`suggested_heading`** incluido en route planner response
- **Metro Sevilla**: shapes OK pero departures vacío (pendiente API)
- **Metro Madrid**: route planner no encuentra rutas (pendiente API)

### 26 Enero 2026
- Migración de `renfeapp.fly.dev` a `redcercanias.com`
- Implementación de sección "Estaciones cercanas a pie"
- Implementación de sección "Andenes"
- Implementación de indicador de Bus
- Implementación de mostrar provincia
- Verificación de shapes para todas las redes
- Verificación de correspondencias Barcelona
- **Bug encontrado**: C10 Madrid incluye `RENFE_4040` (Delicias Zaragoza) en sus paradas
- **Nuevo:** Metro Sevilla L1 añadido con shapes completos (272 puntos, 21 paradas)
  - Ruta: `METRO_SEV_L1_CE_OQ` (Ciudad Expo - Olivar de Quintos)
  - Color: `#0D6928` (verde)
