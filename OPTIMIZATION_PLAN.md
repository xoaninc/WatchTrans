# Plan de Optimizacion - WatchTrans

**Fecha:** 2026-01-30
**Objetivo:** Reducir tiempo de carga inicial y mejorar rendimiento general
**Ultima actualizacion:** 2026-01-30

---

## Estado de Implementacion

| Fase | Descripcion | Estado |
|------|-------------|--------|
| 1.1 | Carga instantanea con ubicacion guardada | ✅ COMPLETADO |
| 1.2 | Cache-first en StopCardView | ✅ COMPLETADO |
| 2.1 | Migrar a LazyVStack | ✅ COMPLETADO |
| 3.1 | Prefetch arrivals de favoritos en paralelo | ✅ COMPLETADO |
| 3.2 | Background App Refresh para iOS | ✅ COMPLETADO (ver nota) |
| 4.x | Optimizaciones menores | ⏳ Opcional |

**Nota FASE 3.2:** Requiere configuracion manual en Xcode (ver instrucciones abajo).

---

## Auditoria del Estado Actual

### Problemas Detectados (RESUELTOS)

| # | Problema | Impacto | Estado |
|---|----------|---------|--------|
| 1 | **No usa LazyVStack** | Alto | ✅ Resuelto |
| 2 | **Espera sincrona de ubicacion** (hasta 15s) | Critico | ✅ Resuelto |
| 3 | **No hay prefetch de favoritos** | Medio | ✅ Resuelto |
| 4 | **Cada StopCard carga arrivals individualmente** | Alto | ✅ Resuelto (cache-first) |
| 5 | **No hay Background App Refresh (iOS)** | Medio | ✅ Resuelto |
| 6 | **Cache no se muestra mientras carga API** | Alto | ✅ Resuelto |

### Lo que Ya Funciona Bien

- [x] Cache en memoria con TTL (20s) - `APIConfiguration.swift`
- [x] Cache en disco para offline - `OfflineScheduleService.swift`
- [x] Auto-refresh cada 25s cuando app activa
- [x] Background refresh en Watch (cada 15min)
- [x] Background refresh en iOS (cada 15min) - NUEVO
- [x] Stale cache como fallback si API falla
- [x] Prefetch de favoritos en paralelo al inicio - NUEVO

---

## Plan de Accion

### FASE 1: Carga Instantanea (PRIORIDAD CRITICA)

#### 1.1 Mostrar UI inmediatamente sin esperar ubicacion

**Problema:** `MainTabView.loadData()` espera hasta 15 segundos por autorizacion + ubicacion antes de mostrar nada.

**Archivo:** `WatchTrans iOS/Views/MainTabView.swift`

**Solucion:**
```swift
private func loadData() async {
    // 1. INMEDIATO: Cargar datos de la ultima ubicacion conocida (SharedStorage)
    if let savedLocation = SharedStorage.shared.getLastLocation() {
        await dataService.fetchTransportData(
            latitude: savedLocation.latitude,
            longitude: savedLocation.longitude
        )
        // UI ya puede mostrar datos!
    }

    // 2. EN PARALELO: Solicitar ubicacion actual
    Task {
        await requestAndUpdateLocation()
    }
}
```

**Resultado esperado:** UI visible en <1 segundo en lugar de 5-15 segundos.

---

#### 1.2 Patron Cache-First en StopCardView

**Problema:** `StopCardView.loadArrivals()` llama a API y muestra spinner mientras espera.

**Archivo:** `WatchTrans iOS/Views/Home/HomeView.swift` (lineas 605-614)

**Codigo actual:**
```swift
private func loadArrivals() async {
    if !hasLoadedOnce {
        isLoading = true  // Muestra spinner
    }
    arrivals = await dataService.fetchArrivals(for: stop.id)  // Espera API
    hasLoadedOnce = true
    isLoading = false
}
```

**Solucion:**
```swift
private func loadArrivals() async {
    // 1. Mostrar cache inmediatamente (si existe)
    if let cached = dataService.getStaleCachedArrivals(for: stop.id) {
        arrivals = cached
        hasLoadedOnce = true
        // No mostrar spinner - ya tenemos datos
    } else if !hasLoadedOnce {
        isLoading = true
    }

    // 2. Actualizar con datos frescos en background
    let fresh = await dataService.fetchArrivals(for: stop.id)
    arrivals = fresh
    hasLoadedOnce = true
    isLoading = false
}
```

**Resultado esperado:** Datos visibles instantaneamente, actualizacion silenciosa.

---

### FASE 2: Rendimiento de Listas (PRIORIDAD ALTA)

#### 2.1 Migrar a LazyVStack

**Problema:** `VStack` renderiza TODOS los elementos inmediatamente. Con muchas paradas/llegadas, causa lag.

**Archivos a modificar:**

| Archivo | Linea | Cambio |
|---------|-------|--------|
| `HomeView.swift` | 44 | `VStack` -> `LazyVStack` |
| `StopDetailView.swift` | (buscar) | `VStack` -> `LazyVStack` |
| `LinesListView.swift` | (buscar) | `VStack` -> `LazyVStack` |
| `SearchView.swift` | (buscar) | `VStack` -> `LazyVStack` |

**Ejemplo:**
```swift
// ANTES
ScrollView {
    VStack(spacing: 20) {
        ForEach(stops) { stop in
            StopCardView(stop: stop)
        }
    }
}

// DESPUES
ScrollView {
    LazyVStack(spacing: 20) {
        ForEach(stops) { stop in
            StopCardView(stop: stop)
        }
    }
}
```

**Nota:** Solo cambiar VStack dentro de ScrollView. Los VStack pequenos (2-3 elementos) pueden quedarse igual.

---

### FASE 3: Prefetch Inteligente (PRIORIDAD MEDIA)

#### 3.1 Cargar arrivals de favoritos en paralelo al inicio

**Problema:** Cada `StopCardView` carga sus arrivals independientemente, causando multiples llamadas secuenciales.

**Archivo:** `WatchTrans iOS/Views/MainTabView.swift`

**Solucion:**
```swift
private func loadData() async {
    // ... codigo existente ...

    // NUEVO: Prefetch arrivals para favoritos en paralelo
    if let manager = favoritesManager {
        let favoriteIds = manager.favorites.map { $0.stopId }
        await withTaskGroup(of: Void.self) { group in
            for stopId in favoriteIds {
                group.addTask {
                    _ = await dataService.fetchArrivals(for: stopId)
                }
            }
        }
    }
}
```

---

#### 3.2 Background App Refresh para iOS

**Problema:** iOS app no tiene background refresh - datos siempre stale al abrir.

**Archivos a crear/modificar:**

1. **Info.plist** - Añadir:
```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.watchtrans.refreshDepartures</string>
</array>
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
</array>
```

2. **Nuevo archivo:** `WatchTrans iOS/Services/BackgroundRefreshService.swift`
```swift
import BackgroundTasks

class BackgroundRefreshService {
    static let shared = BackgroundRefreshService()
    static let taskIdentifier = "com.watchtrans.refreshDepartures"

    func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { task in
            self.handleRefresh(task: task as! BGAppRefreshTask)
        }
    }

    func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleRefresh(task: BGAppRefreshTask) {
        scheduleRefresh() // Programar siguiente

        Task {
            // Cargar arrivals para favoritos
            let favorites = SharedStorage.shared.getFavorites()
            for fav in favorites.prefix(3) {
                _ = try? await GTFSRealtimeService().fetchDepartures(
                    stopId: fav.stopId,
                    limit: 20
                )
            }
            task.setTaskCompleted(success: true)
        }
    }
}
```

3. **AppDelegate/App** - Registrar el servicio al iniciar

---

### FASE 4: Optimizaciones Menores (PRIORIDAD BAJA)

#### 4.1 Reducir re-renders de SwiftUI

**Verificar uso correcto de:**
- `@StateObject` para crear ViewModels
- `@ObservedObject` para ViewModels pasados como parametro
- `Equatable` en modelos para evitar re-renders innecesarios

#### 4.2 Cache de imagenes/logos

Si hay logos de lineas, usar `AsyncImage` con cache o libreria como Kingfisher.

#### 4.3 Profiling con Instruments

Usar Xcode Instruments para identificar:
- Time Profiler: funciones lentas
- Allocations: memory leaks
- Core Animation: drops de frames

---

## Resumen de Cambios por Archivo

| Archivo | Fase | Cambios |
|---------|------|---------|
| `MainTabView.swift` | 1.1, 3.1 | Cache-first startup, prefetch favoritos |
| `HomeView.swift` | 1.2, 2.1 | Cache-first cards, LazyVStack |
| `StopDetailView.swift` | 2.1 | LazyVStack |
| `LinesListView.swift` | 2.1 | LazyVStack |
| `SearchView.swift` | 2.1 | LazyVStack |
| `Info.plist` | 3.2 | Background modes |
| `BackgroundRefreshService.swift` | 3.2 | NUEVO |
| `AppDelegate.swift` | 3.2 | Registrar BGTask |

---

## Metricas de Exito

| Metrica | Actual | Objetivo |
|---------|--------|----------|
| Tiempo hasta UI visible | 5-15s | <1s |
| Tiempo hasta arrivals visibles | 3-5s | <0.5s (cache) |
| Frame rate durante scroll | Variable | 60fps estable |
| Datos frescos al abrir (con BG refresh) | No | Si |

---

## Orden de Implementacion Recomendado

1. **FASE 1.1** - Carga instantanea con ubicacion guardada (mayor impacto)
2. **FASE 1.2** - Cache-first en StopCardView
3. **FASE 2.1** - LazyVStack en todas las listas
4. **FASE 3.1** - Prefetch de favoritos en paralelo
5. **FASE 3.2** - Background App Refresh

---

## Notas Adicionales

### TTLs Actuales (APIConfiguration.swift)
- `autoRefreshInterval`: 25 segundos
- `arrivalCacheTTL`: 20 segundos
- `staleCacheGracePeriod`: 300 segundos (5 min)

Estos valores son apropiados para datos de transporte en tiempo real.

### Watch App
La Watch App ya tiene `BackgroundRefreshService` implementado.

### iOS App - Background Refresh (NUEVO)
La iOS App ahora tambien tiene `BackgroundRefreshService` implementado.

### Compatibilidad
- `LazyVStack` requiere iOS 14+
- `BGTaskScheduler` requiere iOS 13+
- App actual: iOS 15+ (compatible)

---

## Configuracion Manual Requerida (FASE 3.2)

Para que Background App Refresh funcione en iOS, debes configurar en Xcode:

### 1. Habilitar Background Modes

1. Abre el proyecto en Xcode
2. Selecciona el target **WatchTrans iOS**
3. Ve a la pestana **Signing & Capabilities**
4. Click en **+ Capability**
5. Busca y anade **Background Modes**
6. Marca la casilla **Background fetch**

### 2. Anadir BGTaskSchedulerPermittedIdentifiers

En el mismo target, ve a **Info** y anade:

| Key | Type | Value |
|-----|------|-------|
| `BGTaskSchedulerPermittedIdentifiers` | Array | |
| Item 0 | String | `juan.WatchTrans.refreshDepartures` |

O directamente en Info.plist (si existe):

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>juan.WatchTrans.refreshDepartures</string>
</array>
```

### 3. Verificar funcionamiento

Para probar background refresh en el simulador:

```bash
# Pausar la app en el debugger, luego ejecutar:
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"juan.WatchTrans.refreshDepartures"]
```

En dispositivo real, el sistema decide cuando ejecutar el task basado en patrones de uso.
