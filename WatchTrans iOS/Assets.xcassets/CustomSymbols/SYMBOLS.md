# Custom Symbols Reference

Pictogramas custom usados en WatchTrans. Todos se renderizan con `.renderingMode(.template)` para tinting.

## TransportType enum

La app usa `TransportType` (5 cases) basado en el campo `route_type` GTFS de la API:

| Case | route_type | Color | Cubre |
|------|-----------|-------|-------|
| `.metro` | 1 | `.orange` | Metro Madrid, Metro Sevilla, TMB Metro, Metro Bilbao, Metro Ligero... |
| `.tren` | 2 | `.blue` | Cercanías, Rodalies, FGC, Euskotren, FEVE, SFM Mallorca... |
| `.tram` | 0 | `.green` | Tranvías (Sevilla, Zaragoza, Murcia, Barcelona, Tenerife...) |
| `.bus` | 3 | `.red` | Buses |
| `.funicular` | 7 | `.brown` | Funiculares |

**Eliminados en esta sesión:** `.metroLigero` (fusionado con `.metro`), `.fgc` (fusionado con `.tren`), `.euskotren` (fusionado con `.tren`).

**Nota:** `TransportMode` (Journey planner) y `LogoType` (LogoImageView) son enums internos separados que SÍ mantienen `.metroLigero`, `.fgc`, `.euskotren` para logos de operadores y modos de transporte de la API.

## Assets custom

### AIGA/DOT (Dominio público)

Fuente: https://commons.wikimedia.org/wiki/Category:AIGA_symbol_signs

| Asset | Qué es | Para qué se usa | Dónde en la app |
|-------|--------|-----------------|-----------------|
| `ElevatorSymbol` | Ascensor (persona dentro de una cabina con flechas arriba/abajo) | Mostrar ascensores de estación y su estado operativo en tiempo real (verde=operativo, rojo=fuera de servicio). En accesos, indica que la entrada tiene ascensor. | `EquipmentStatusSection` (estado RT ascensores Metro Sevilla), `AccessRow` (accesos accesibles) |
| `EscalatorSymbol` | Escalera mecánica (persona en escalera con pasamanos, sin dirección) | Mostrar escaleras mecánicas sin dirección conocida. En pathways indica que el recorrido incluye una escalera mecánica. | `EquipmentStatusSection` (escaleras mecánicas sin dirección), `PathwayRow` (recorridos) |
| `EscalatorUpSymbol` | Escalera mecánica subiendo (persona en escalera + flecha arriba) | Mostrar escalera mecánica que sube, con estado operativo RT. | `EquipmentStatusSection` (escalera mecánica dirección subida) |
| `EscalatorDownSymbol` | Escalera mecánica bajando (persona en escalera + flecha abajo) | Mostrar escalera mecánica que baja, con estado operativo RT. | `EquipmentStatusSection` (escalera mecánica dirección bajada) |
| `StairsSymbol` | Escaleras normales (persona subiendo peldaños) | Indicar que un recorrido dentro de la estación incluye escaleras. | `PathwayRow` (recorridos con escaleras en interior de estación) |

### ISO 7001 (Wikimedia Commons, recreación comunitaria)

Fuente: https://commons.wikimedia.org/wiki/Category:ISO_7001_icons

| Asset | SVG original | Qué es | Para qué se usa | Estado |
|-------|-------------|--------|-----------------|--------|
| `MetroSymbol` | `ISO_7001_PI_TF_003.svg` | Metro/underground (tren entrando en túnel con pasajeros) | Indicar que la parada/línea es de metro. Sustituye SF Symbol `tram.tunnel.fill`. | **Pendiente integrar en código** |
| `TrenSymbol` | `ISO_7001_PI_TF_002.svg` | Tren/ferrocarril (locomotora con vagón) | Indicar que la parada/línea es de tren (cercanías, regional). Sustituye SF Symbol `tram.fill`. | **Pendiente integrar en código** |
| `TramSymbol` | `ISO_7001_PI_TF_007.svg` | Tranvía/streetcar (tranvía con catenaria) | Indicar que la parada/línea es de tranvía. Sustituye SF Symbol `lightrail.fill`. | **Pendiente integrar en código** |
| `BusSymbol` | `ISO_7001_PI_TF_006.svg` | Autobús (bus visto de lado) | Indicar que la parada/línea es de bus. Sustituye SF Symbol `bus.fill`. | **Pendiente integrar en código** |
| `FunicularSymbol` | `ISO_7001_PI_TF_012.svg` | Funicular (tren inclinado subiendo pendiente) | Indicar que la parada es de funicular. | ✅ Integrado en `StopDetailView` |
| `WheelchairSymbol` | `ISO_7001_PI_PF_006.svg` | Persona en silla de ruedas | Indicar accesibilidad. Sustituye SF Symbol `figure.roll`. Colores via `.foregroundStyle()`: verde=accesible, rojo=no accesible (con overlay ISO 7001 Red Slash o Red Cross), azul=header/badge. | **Pendiente integrar en código** |

### Otros (revisar licencia)

| Asset | Qué es | Para qué se usa | Dónde en la app |
|-------|--------|-----------------|-----------------|
| `StairClimbingSymbol` | Monigote subiendo escaleras (silueta lateral) | Indicar que un acceso/entrada a la estación es por escaleras (no tiene ascensor ni rampa). | `AccessRow` (accesos no accesibles en interior de estación) |

## SF Symbols (Apple, incluidos con iOS)

### Transporte

| SF Symbol | Qué es | Para qué se usa | Dónde en la app |
|-----------|--------|-----------------|-----------------|
| `tram.fill` | Tranvía/tren relleno | **Será sustituido por `TrenSymbol` (ISO 7001)**. Icono genérico de transporte ferroviario. | `ArrivalRowView`, `TrainDetailView`, `StopDetailView`, `FullMapView`, `TrainAnnotationView`, `NativeAnimatedMapView`, `LogoImageView`, `SettingsView`, `PlanRouteIntent`, widgets, Watch |
| `tram.tunnel.fill` | Tren saliendo de túnel | **Será sustituido por `MetroSymbol` (ISO 7001)**. Indicar metro. | `StopDetailView` badge "Metro", `FullMapView`, `LogoImageView`, `SettingsView` |
| `lightrail.fill` | Tren ligero relleno | **Será sustituido por `TramSymbol` (ISO 7001)**. Indicar tranvía/tram. | `StopDetailView` badge "Tram", `FullMapView`, `NativeAnimatedMapView`, `LogoImageView`, `Journey` model |
| `tram` | Tranvía sin relleno | **Será sustituido por `TramSymbol` (ISO 7001)**. Journey planner. | `Journey` model (modo tranvía) |
| `train.side.front.car` | Tren visto de lado | Indicar vía/andén de un tren. Modo cercanías en planificador. | `TrainDetailView` badge "Vía", `StopDetailView` Acerca "Andén", `NativeAnimatedMapView`, `Journey` model, Watch `TrainDetailView` |
| `bus.fill` | Autobús relleno | **Será sustituido por `BusSymbol` (ISO 7001)**. Indicar bus o servicio alternativo. | `StopDetailView` badge "Bus", `ArrivalRowView`, `LinesListView`, `FullMapView`, `NativeAnimatedMapView`, `Journey` model |

### Accesibilidad

| SF Symbol | Qué es | Para qué se usa | Dónde en la app |
|-----------|--------|-----------------|-----------------|
| `figure.roll` | Persona en silla de ruedas | **Será sustituido por `WheelchairSymbol` (ISO 7001)**. Verde=accesible, rojo+xmark=no accesible, azul=header. | `ArrivalRowView`, `TrainDetailView`, `StopDetailView`, `EquipmentStatusSection` (header), `StationInteriorSection` |
| `figure.walk` | Persona andando | Indicar recorrido a pie. | `PathwayRow`, `JourneyPlannerView`, `StopDetailView`, `PlanRouteIntent` |
| `figure.stairs` | Persona subiendo escaleras | **No se usa** — sustituido por `StairsSymbol` AIGA en pathways. | — |
| `bicycle` | Bicicleta | Indicar bicicletas permitidas o parking bici. | `ArrivalRowView`, `StopDetailView` badge "Parking Bici" |

### Equipamiento / Servicios

| SF Symbol | Qué es | Para qué se usa | Dónde en la app |
|-----------|--------|-----------------|-----------------|
| `door.left.hand.open` | Puerta abierta | Entrada sin ascensor. Entrada en journey planner. Vestíbulo en Acerca PMR. | `StationInteriorSection`, `StopDetailView` mapa, `JourneyPlannerView`, `StopDetailView` Acerca |
| `door.right.hand.open` | Puerta abierta (derecha) | Salida de estación en journey planner. | `JourneyPlannerView` |
| `creditcard` | Tarjeta | Torniquete/fare gate en recorridos. | `PathwayRow` |
| `arrow.left.arrow.right` | Flechas izq-der | Pasillo mecánico/cinta en recorridos. | `PathwayRow` |
| `moon.zzz.fill` | Luna con zzz | Equipos apagados por cierre nocturno. | `EquipmentStatusSection` |

### UI general

| SF Symbol | Qué es | Para qué se usa |
|-----------|--------|-----------------|
| `exclamationmark.triangle.fill` | Triángulo de alerta | Alertas, retrasos, PMR warning |
| `xmark` | Cruz | Superpuesto sobre `figure.roll` para "no accesible" |
| `location.fill` / `location.slash` | Pin de ubicación | Posición del tren, ubicación usuario |
| `star.fill` / `star` | Estrella | Favoritos |
| `clock` / `clock.fill` | Reloj | Horarios, salidas |
| `chevron.right` / `chevron.up` / `chevron.down` | Flechas | Navegación, expandir/contraer |
| `icloud.slash` | iCloud tachado | Datos offline |
| `mappin.circle` | Pin de mapa | Punto de encuentro Acerca PMR |

## Fuentes completas disponibles

### AIGA/DOT Symbol Signs (82 archivos SVG)

Carpeta: `symbol_signs_aiga_svg/`

Set completo de ~50 pictogramas + variantes descargados como SVG de https://commons.wikimedia.org/wiki/Category:AIGA_symbol_signs

**No se usan para transporte** (se eligió ISO 7001 para metro/tren/tram/bus). Sí se usan para equipamiento (elevator, escalator, stairs).

**Licencia**: Dominio público (US Government work, 1974). **Marco legal pendiente de verificar** — ver KNOWN_ISSUES.md.

### ISO 7001 (Wikimedia Commons)

Carpeta: `iso_7001_wikimedia_svg/`

191 SVGs descargados de https://commons.wikimedia.org/wiki/Category:ISO_7001_icons. Recreaciones comunitarias.

Símbolos de transporte relevantes (PI TF):

| Archivo | Qué es |
|---------|--------|
| `ISO_7001_PI_TF_001.svg` | Aeropuerto/avión |
| `ISO_7001_PI_TF_002.svg` | Estación de tren/ferrocarril |
| `ISO_7001_PI_TF_003.svg` | Metro/underground |
| `ISO_7001_PI_TF_004.svg` | Puerto/barcos/ferry |
| `ISO_7001_PI_TF_005.svg` | Helipuerto |
| `ISO_7001_PI_TF_006.svg` | Parada de bus |
| `ISO_7001_PI_TF_007.svg` | Tranvía/streetcar |
| `ISO_7001_PI_TF_008.svg` | Parada de taxi |
| `ISO_7001_PI_TF_009.svg` | Alquiler de coches |
| `ISO_7001_PI_TF_010.svg` | Bicicleta |
| `ISO_7001_PI_TF_011.svg` | Teleférico/cable car |
| `ISO_7001_PI_TF_012.svg` | Funicular ← **usado como FunicularSymbol** |
| `ISO_7001_PI_TF_014.svg` | Parking |
| `ISO_7001_PI_TF_024.svg` | Asientos prioritarios |
| `ISO_7001_PI_TF_040.svg` | Embarque bus |
| `ISO_7001_PI_TF_044.svg` | Carga vehículo eléctrico |

**Licencia**: Cada SVG tiene su propia licencia en Wikimedia (generalmente CC0 o CC BY-SA). Los originales ISO 7001 son copyright ISO. **Marco legal pendiente** — ver KNOWN_ISSUES.md.

### Otras fuentes pendientes de evaluar

| Fuente | Licencia | URL | Estado |
|--------|----------|-----|--------|
| Temaki | CC0 | https://github.com/rapideditor/temaki | Pendiente |
| Maki (Mapbox) | CC0 | https://github.com/mapbox/maki | Pendiente |
| Material Design Icons | Apache 2.0 | https://fonts.google.com/icons | Pendiente |
| Accesibiliconos | CC BY-SA 4.0 | https://accesibiliconos.org/ | Pendiente |
| JIS Z8210 | Revisar | https://github.com/cat-in-136/JISZ8210_Symbols_SVG | Pendiente |
| SBB Picto Library | Revisar | https://github.com/sbb-design-systems/picto-library | Pendiente |

## Licencias

- **AIGA/DOT Symbol Signs**: Dominio público (US Government work, 1974). **Marco legal pendiente de verificar.**
- **ISO 7001 (Wikimedia)**: Recreaciones comunitarias, licencia por archivo. Originales copyright ISO (~$30/símbolo). **Marco legal pendiente.**
- **StairClimbingSymbol**: Fuente por determinar. Revisar licencia antes de publicar.
- **SF Symbols**: Incluidos con iOS/watchOS. Uso permitido en apps Apple.

## Migración pendiente: SF Symbols → ISO 7001 custom assets

Decisión tomada: usar ISO 7001 (Wikimedia) para los 5 modos de transporte. Assets creados, pendiente integrar en código.

| SF Symbol actual | Sustituir por | Archivos afectados (aprox) |
|-----------------|---------------|---------------------------|
| `tram.fill` | `TrenSymbol` | ~15 archivos (iOS + Watch + widgets) |
| `tram.tunnel.fill` | `MetroSymbol` | ~5 archivos |
| `lightrail.fill` / `tram` | `TramSymbol` | ~5 archivos |
| `bus.fill` | `BusSymbol` | ~5 archivos |
| `figure.roll` | `WheelchairSymbol` | ~10 archivos (colores via foregroundStyle, overlay para "no accesible" pendiente decidir: ISO 7001 Red Slash o Red Cross) |

**Nota:** `train.side.front.car` NO se sustituye — se usa para "Vía/Andén", no como modo de transporte.

**Impacto:** Cada `Image(systemName: "xxx")` o `Label("", systemImage: "xxx")` necesita cambiar a `Image("XxxSymbol").renderingMode(.template).resizable().scaledToFit()` con frame explícito.

## Bugs / datos de la API sin símbolo

### `corBus` — correspondencia bus no se muestra

El campo `corBus` existe en el modelo `Stop` y se decodifica de la API, pero en `StopDetailView` los badges de correspondencia bus **nunca se añaden** a `allBadges`. Necesita implementación.

## Pendiente (KNOWN_ISSUES.md)

- Marco legal AIGA y ISO 7001 Wikimedia
- Revisar licencia de StairClimbingSymbol
- Implementar badges de correspondencia bus (`corBus`)
- Evaluar fuentes adicionales (Temaki, Maki, Material Design, Accesibiliconos)
- Colores de TransportType pendientes de validar por el usuario
