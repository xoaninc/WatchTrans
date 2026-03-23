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

| Asset | Qué es | Para qué se usa | Dónde en la app |
|-------|--------|-----------------|-----------------|
| `FunicularSymbol` | Funicular (tren inclinado subiendo pendiente con vagones) | Indicar que la parada es de funicular. | `StopDetailView` badge "Funicular" |

### Otros (revisar licencia)

| Asset | Qué es | Para qué se usa | Dónde en la app |
|-------|--------|-----------------|-----------------|
| `StairClimbingSymbol` | Monigote subiendo escaleras (silueta lateral) | Indicar que un acceso/entrada a la estación es por escaleras (no tiene ascensor ni rampa). | `AccessRow` (accesos no accesibles en interior de estación) |

## SF Symbols (Apple, incluidos con iOS)

### Transporte

| SF Symbol | Qué es | Para qué se usa | Dónde en la app |
|-----------|--------|-----------------|-----------------|
| `tram.fill` | Tranvía/tren relleno | Icono genérico de transporte ferroviario. Se usa como icono por defecto para tren. | `ArrivalRowView`, `TrainDetailView`, `StopDetailView` (mapa, badge "Tren"), `FullMapView`, `TrainAnnotationView`, `NativeAnimatedMapView`, `LogoImageView`, `SettingsView`, `PlanRouteIntent`, widgets iOS/Watch, `LiveActivityWidget`, Watch `ArrivalCard` |
| `tram.tunnel.fill` | Tren saliendo de túnel | Indicar metro (subterráneo). | `StopDetailView` badge "Metro", `FullMapView` (tipo metro), `LogoImageView`, `SettingsView` (credits) |
| `lightrail.fill` | Tren ligero relleno | Indicar tranvía/tram. | `StopDetailView` badge "Tram", `FullMapView` (tipo tram), `NativeAnimatedMapView`, `LogoImageView`, `Journey` model (modo metro ligero) |
| `tram` | Tranvía sin relleno | Modo de transporte tranvía en el planificador de rutas. | `Journey` model (modo tranvía) |
| `train.side.front.car` | Tren visto de lado | Indicar vía/andén de un tren. Modo cercanías en planificador. | `TrainDetailView` badge "Vía", `StopDetailView` Acerca "Andén", `NativeAnimatedMapView`, `Journey` model (modo cercanías), Watch `TrainDetailView` |
| `bus.fill` | Autobús relleno | Indicar parada de bus o servicio alternativo por autobús. | `StopDetailView` badge "Bus", `ArrivalRowView` (servicio alternativo), `LinesListView`, `FullMapView`, `NativeAnimatedMapView`, `Journey` model (modo bus) |

### Accesibilidad

| SF Symbol | Qué es | Para qué se usa | Dónde en la app |
|-----------|--------|-----------------|-----------------|
| `figure.roll` | Persona en silla de ruedas | Indicar accesibilidad. Verde = accesible (RT o static == 2). Rojo + xmark = no accesible (== 3). Azul = header/badge parada. | `ArrivalRowView`, `TrainDetailView`, `StopDetailView`, `EquipmentStatusSection` (header), `StationInteriorSection` |
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

### AIGA/DOT Symbol Signs (68 archivos EPS)

Carpeta: `symbol_signs_aiga_eps/`

Set completo de 50 pictogramas + flechas direccionales descargado de https://www.aiga.org/resources/symbol-signs

Relevantes para transporte y accesibilidad:

| Archivo | Qué es |
|---------|--------|
| `ss_09_Escalator.eps` | Escalera mecánica |
| `ss_10_Escalator-down.eps` | Escalera mecánica bajada |
| `ss_11_Escalator-up.eps` | Escalera mecánica subida |
| `ss_12_Stairs.eps` | Escaleras |
| `ss_13_Stairs-down.eps` | Escaleras bajada |
| `ss_14_Stairs-up.eps` | Escaleras subida |
| `ss_15_Elevator.eps` | Ascensor |
| `ss_24_Air-Transportation.eps` | Transporte aéreo |
| `ss_25_Heliport.eps` | Helipuerto |
| `ss_26_Taxi.eps` | Taxi |
| `ss_27_Bus.eps` | Autobús |
| `ss_28_Ground-transportation.eps` | Transporte terrestre |
| `ss_29_Rail-Transportation.eps` | Transporte ferroviario |
| `ss_30_Water-Transportation.eps` | Transporte marítimo |
| `ss_39_TicketPurchase.eps` | Compra de billetes |
| `ss_46_Parking.eps` | Parking |
| `ss_50_Exit.eps` | Salida |

**Licencia**: Descrito como dominio público (US Government work, 1974). **Marco legal pendiente de verificar** — ver KNOWN_ISSUES.md.

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

## Bugs / datos de la API sin símbolo

### `corBus` — correspondencia bus no se muestra

El campo `corBus` existe en el modelo `Stop` y se decodifica de la API, pero en `StopDetailView` los badges de correspondencia bus **nunca se añaden** a `allBadges`. Necesita implementación.

## Pendiente (KNOWN_ISSUES.md)

- Marco legal AIGA y ISO 7001 Wikimedia
- Revisar licencia de StairClimbingSymbol
- Implementar badges de correspondencia bus (`corBus`)
- Evaluar fuentes adicionales (Temaki, Maki, Material Design, Accesibiliconos)
- Colores de TransportType pendientes de validar por el usuario
