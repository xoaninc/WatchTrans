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

Anteriormente existían `.metroLigero`, `.fgc`, `.euskotren` — fusionados en `.metro`/`.tren` respectivamente.

`LogoImageView` ya no tiene enum `LogoType` — solo recibe `TransportType` y muestra el icono genérico. Cuando la API envíe `logo` en `/networks`, se añadirá carga remota.

## Assets custom

### AIGA/DOT (Dominio público)

Fuente: https://commons.wikimedia.org/wiki/Category:AIGA_symbol_signs

| Asset | Qué es | Para qué se usa | Dónde en la app |
|-------|--------|-----------------|-----------------|
| `ElevatorSymbol` | Ascensor (persona dentro de una cabina con flechas arriba/abajo) | Mostrar ascensores de estación y su estado operativo en tiempo real (verde=operativo, rojo=fuera de servicio). En accesos, indica que la entrada tiene ascensor. | `EquipmentStatusSection` (estado RT ascensores Metro Sevilla), `AccessRow` (accesos accesibles) |
| `EscalatorSymbol` | Escalera mecánica (persona en escalera con pasamanos, sin dirección) | Mostrar escaleras mecánicas sin dirección conocida. En pathways indica que el recorrido incluye una escalera mecánica. | `EquipmentStatusSection` (escaleras mecánicas sin dirección), `PathwayRow` (recorridos) |
| `EscalatorUpSymbol` | Escalera mecánica subiendo (persona en escalera + flecha arriba) | Mostrar escalera mecánica que sube, con estado operativo RT. | `EquipmentStatusSection` (escalera mecánica dirección subida) |
| `EscalatorDownSymbol` | Escalera mecánica bajando (persona en escalera + flecha abajo) | Mostrar escalera mecánica que baja, con estado operativo RT. | `EquipmentStatusSection` (escalera mecánica dirección bajada) |
| `StairsSymbol` | Escaleras normales (persona subiendo peldaños) | **Ya no se usa** — sustituido por `StairClimbingSymbol`. Pendiente eliminar imageset. | — |

### ISO 7001 (Wikimedia Commons, recreación comunitaria)

Fuente: https://commons.wikimedia.org/wiki/Category:ISO_7001_icons

| Asset | SVG original | Qué es | Para qué se usa | Estado |
|-------|-------------|--------|-----------------|--------|
| `MetroSymbol` | `ISO_7001_PI_TF_003.svg` | Metro/underground | Parada/línea de metro. Sustituye `tram.tunnel.fill`. | ✅ Integrado |
| `TrenSymbol` | `ISO_7001_PI_TF_002.svg` | Tren/ferrocarril | Parada/línea de tren (cercanías, regional). Sustituye `tram.fill`. | ✅ Integrado |
| `TramSymbol` | `ISO_7001_PI_TF_007.svg` | Tranvía/streetcar | Parada/línea de tranvía. Sustituye `lightrail.fill`. | ✅ Integrado |
| `BusSymbol` | `ISO_7001_PI_TF_006.svg` | Autobús | Parada/línea de bus. Sustituye `bus.fill`. | ✅ Integrado |
| `FunicularSymbol` | `ISO_7001_PI_TF_012.svg` | Funicular | Parada de funicular. | ✅ Integrado |
| `WheelchairSymbol` | `ISO_7001_PI_PF_006.svg` | Persona en silla de ruedas | Accesibilidad. Verde=accesible, azul=header. No accesible: overlay `RedCrossOverlay`. Valores: RT protobuf (2=accesible, 3=no), static GTFS (1=accesible, 2=no). `wheelchairValue()` normaliza static→RT. | ✅ Integrado |
| `RedCrossOverlay` | `ISO_7001_-_Red_Cross.svg` | Cruz roja | Overlay "NO ES" sobre cualquier símbolo. No para fuera de servicio ni inexistente. | ✅ Integrado |

### Otros (revisar licencia)

| Asset | Qué es | Para qué se usa | Dónde en la app |
|-------|--------|-----------------|-----------------|
| `StairClimbingSymbol` | Monigote subiendo escaleras (silueta lateral) | Indicar escaleras en todos los contextos: accesos y recorridos. | `AccessRow` (accesos), `PathwayRow` (recorridos), `StopDetailView` (mapa pins) |

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
| `figure.roll` | Persona en silla de ruedas | **Será sustituido por `WheelchairSymbol` (ISO 7001)**. Verde=accesible, overlay Red Cross=no es accesible, azul=header. | `ArrivalRowView`, `TrainDetailView`, `StopDetailView`, `EquipmentStatusSection` (header), `StationInteriorSection` |
| `figure.walk` | Persona andando | Indicar recorrido a pie. | `PathwayRow`, `JourneyPlannerView`, `StopDetailView`, `PlanRouteIntent` |
| `figure.stairs` | Persona subiendo escaleras | **No se usa** — sustituido por `StairsSymbol` AIGA en pathways. | — |
| `bicycle` | Bicicleta | Indicar bicicletas permitidas o parking bici. | `ArrivalRowView`, `StopDetailView` badge "Parking Bici" |

### Equipamiento / Servicios

| SF Symbol | Qué es | Para qué se usa | Dónde en la app |
|-----------|--------|-----------------|-----------------|
| `door.left.hand.open` | Puerta abierta | Entrada en journey planner. Vestíbulo en Acerca PMR (Acerca no terminado). **Bug: sigue en mapa de pins de accesos** (`StopDetailView:97`) — todos los pins deberían usar `StairClimbingSymbol` (es una entrada). La accesibilidad se indica aparte, no con el icono del pin. | `JourneyPlannerView` (entrada), `StopDetailView` mapa accesos (**pendiente corregir**), `StopDetailView` Acerca (no terminado) |
| `door.right.hand.open` | Puerta abierta (derecha) | Salida de estación en journey planner. | `JourneyPlannerView` |
| `creditcard` | Tarjeta | Torniquete/fare gate en recorridos. | `PathwayRow` |
| `arrow.left.arrow.right` | Flechas izq-der | Pasillo mecánico/cinta en recorridos. | `PathwayRow` |
| `moon.zzz.fill` | Luna con zzz | Equipos apagados por cierre nocturno. | `EquipmentStatusSection` |

### Calidad del aire (Metro Sevilla)

| SF Symbol | Qué es | Para qué se usa | Dónde en la app |
|-----------|--------|-----------------|-----------------|
| `aqi.medium` | Indicador calidad aire | Indicar calidad del aire del tren. | `ArrivalRowView` (badge), `TrainDetailView` (sección calidad del aire) |
| `thermometer.medium` | Termómetro | Temperatura dentro del tren. | `TrainDetailView` (calidad del aire) |
| `humidity` | Gota de agua | Humedad dentro del tren. | `TrainDetailView` (calidad del aire) |
| `leaf.fill` | Hoja | Nivel de CO2 / calidad general. | `TrainDetailView` (calidad del aire) |

### Ocupación (TMB Metro)

| SF Symbol | Qué es | Para qué se usa | Dónde en la app |
|-----------|--------|-----------------|-----------------|
| `person` | 1 persona | Ocupación baja. | `ArrivalRowView` (badge ocupación) |
| `person.2` | 2 personas | Ocupación media. | `ArrivalRowView` (badge ocupación) |
| `person.3` | 3 personas | Ocupación alta. | `ArrivalRowView` (badge ocupación) |

### Tren / Viaje

| SF Symbol | Qué es | Para qué se usa | Dónde en la app |
|-----------|--------|-----------------|-----------------|
| `number` | Símbolo # | Código operativo del tren (ej: "75106"). | `TrainDetailView` |
| `repeat` | Flechas circulares | Composición doble (Doble). | `TrainDetailView` |
| `cablecar.fill` | Teleférico | **Bug:** Usado para `.tranvia` en `NativeAnimatedMapView:427` — debería ser `TramSymbol`. Un tranvía no es un teleférico. |

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

**Licencia**: Dominio público (US Government work, 1974). **Marco legal pendiente de verificar** — ver `docs/pending.md#marco-legal-de-símbolos`.

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

**Licencia**: Cada SVG tiene su propia licencia en Wikimedia (generalmente CC0 o CC BY-SA). Los originales ISO 7001 son copyright ISO. **Marco legal pendiente** — ver `docs/pending.md#marco-legal-de-símbolos`.

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

## Migración completada: SF Symbols → ISO 7001 custom assets ✅

| SF Symbol | Sustituido por | Estado |
|-----------|---------------|--------|
| `tram.fill` | `TrenSymbol` | ✅ (excepto AppShortcuts — requiere SF Symbol) |
| `tram.tunnel.fill` | `MetroSymbol` | ✅ |
| `lightrail.fill` / `tram` | `TramSymbol` | ✅ |
| `bus.fill` | `BusSymbol` | ✅ (excepto AlternativeTransport.icon — API siempre null) |
| `figure.roll` | `WheelchairSymbol` + `NegatedSymbolView` | ✅ |
| `cablecar.fill` | `TramSymbol` (era bug) | ✅ |
| `StairsSymbol` | `StairClimbingSymbol` | ✅ |
| Map pins `door.left.hand.open` | `StairClimbingSymbol` | ✅ |

**Helper:** `SymbolView(name:size:)` y `NegatedSymbolView(name:size:)` en `Components/SymbolView.swift` (iOS + Watch).

**Red Cross overlay:** Solo para "NO ES" (ej: tren no accesible). No para fuera de servicio (color rojo) ni inexistente (sin icono).

## Símbolos en el código que NO existen en la API

Los siguientes pathway modes están mapeados a iconos en `PathwayRow` pero **ninguna estación de la API los devuelve actualmente**. Se añadieron preventivamente para cubrir la spec GTFS:

| Pathway mode | Icono actual | Existe en API |
|-------------|-------------|---------------|
| `walkway` | `figure.walk` (SF) | ✅ Sí (TMB, Metro Madrid) |
| `stairs` | `StairsSymbol` (AIGA) | ✅ Sí (TMB) |
| `moving_sidewalk` | `arrow.left.arrow.right` (SF) | ❌ No |
| `escalator` | `EscalatorSymbol` (AIGA) | ❌ No (en pathways; sí en EquipmentStatus) |
| `elevator` | `ElevatorSymbol` (AIGA) | ❌ No (en pathways; sí en EquipmentStatus) |
| `fare_gate` | `creditcard` (SF) | ❌ No |

**Pendiente:** Decidir si quitar los que no se usan o mantenerlos como código defensivo.

## Bugs / datos de la API sin símbolo

### `corBus` — correspondencia bus no se muestra

El campo `corBus` existe en el modelo `Stop` y se decodifica de la API, pero en `StopDetailView` los badges de correspondencia bus **nunca se añaden** a `allBadges`. Necesita implementación.

## Pendiente (docs/pending.md)

- Marco legal AIGA y ISO 7001 Wikimedia
- Revisar licencia de StairClimbingSymbol
- Implementar badges de correspondencia bus (`corBus`)
- Evaluar fuentes adicionales (Temaki, Maki, Material Design, Accesibiliconos)
- Colores de TransportType pendientes de validar por el usuario
