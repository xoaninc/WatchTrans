# Custom Symbols Reference

Pictogramas custom usados en WatchTrans. Todos se renderizan con `.renderingMode(.template)` para tinting.

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

### Otros (revisar licencia)

| Asset | Qué es | Para qué se usa | Dónde en la app |
|-------|--------|-----------------|-----------------|
| `StairClimbingSymbol` | Monigote subiendo escaleras (silueta lateral) | Indicar que un acceso/entrada a la estación es por escaleras (no tiene ascensor ni rampa). | `AccessRow` (accesos no accesibles en interior de estación) |

## SF Symbols (Apple, incluidos con iOS)

### Transporte

| SF Symbol | Qué es | Para qué se usa | Dónde en la app |
|-----------|--------|-----------------|-----------------|
| `tram.fill` | Tranvía/tren relleno | Icono genérico de transporte ferroviario. Se usa para todo tipo de servicio ferroviario como icono por defecto. | `ArrivalRowView`, `TrainDetailView` (posición tren, vehículo, timeline), `StopDetailView` (mapa), `FullMapView` (anotaciones), `TrainAnnotationView`, `NativeAnimatedMapView`, `LogoImageView`, `SettingsView`, `PlanRouteIntent`, widgets iOS/Watch, `LiveActivityWidget`, Watch `ArrivalCard`, Watch `TrainDetailView` |
| `tram.tunnel.fill` | Tren saliendo de túnel | Indicar metro (subterráneo). | `StopDetailView` badge "Metro", `FullMapView` (tipo metro), `LogoImageView`, `SettingsView` (credits de todos los metros) |
| `lightrail.fill` | Tren ligero relleno | Indicar tranvía/tram o metro ligero. | `StopDetailView` badge "Tram", `FullMapView` (tipo tram), `NativeAnimatedMapView`, `LogoImageView`, `Journey` model (modo metro ligero) |
| `tram` | Tranvía sin relleno | Modo de transporte tranvía en el planificador de rutas. | `Journey` model (modo tranvía) |
| `train.side.front.car` | Tren visto de lado | Indicar vía/andén de un tren. Modo cercanías en planificador. | `TrainDetailView` badge "Vía", `StopDetailView` Acerca "Andén", `NativeAnimatedMapView`, `Journey` model (modo cercanías), Watch `TrainDetailView` (andén) |
| `bus.fill` | Autobús relleno | Indicar parada de bus o servicio alternativo por autobús. | `StopDetailView` badge "Bus", `ArrivalRowView` (servicio alternativo), `LinesListView` (indicador alternativo), `FullMapView` (tipo bus), `NativeAnimatedMapView`, `Journey` model (modo bus) |

### Accesibilidad

| SF Symbol | Qué es | Para qué se usa | Dónde en la app |
|-----------|--------|-----------------|-----------------|
| `figure.roll` | Persona en silla de ruedas | Indicar accesibilidad. Verde = accesible. Rojo + xmark superpuesto = no accesible. | `ArrivalRowView` (por tren), `TrainDetailView`, `StopDetailView` (por parada), `EquipmentStatusSection` (header), `StationInteriorSection` (accesos no accesibles) |
| `figure.walk` | Persona andando | Indicar recorrido a pie entre estaciones o dentro de la estación. | `PathwayRow` (recorrido tipo walkway), `JourneyPlannerView` (segmento andando, tiempo caminando), `StopDetailView` (entrada cercana, estaciones cercanas), `PlanRouteIntent` |
| `figure.stairs` | Persona subiendo escaleras | **No se usa** — sustituido por `StairsSymbol` AIGA en pathways. | — |
| `bicycle` | Bicicleta | Indicar que el tren permite bicicletas o que la estación tiene parking de bici. | `ArrivalRowView` (bicicletas permitidas), `StopDetailView` badge "Parking Bici" |

### Equipamiento / Servicios

| SF Symbol | Qué es | Para qué se usa | Dónde en la app |
|-----------|--------|-----------------|-----------------|
| `door.left.hand.open` | Puerta abierta (pomo izquierda) | Entrada a estación sin ascensor. También para indicar entrada en journey planner y vestíbulo en Acerca PMR. | `StationInteriorSection` (accesos sin ascensor), `StopDetailView` mapa de accesos, `JourneyPlannerView` (entrada), `StopDetailView` Acerca (vestíbulo) |
| `door.right.hand.open` | Puerta abierta (pomo derecha) | Indicar punto de salida de la estación en el planificador de rutas. | `JourneyPlannerView` (salida) |
| `creditcard` | Tarjeta de crédito | Indicar torniquete o puerta de tarifa en recorridos dentro de estación. | `PathwayRow` (recorrido tipo fare gate) |
| `arrow.left.arrow.right` | Flechas izquierda-derecha | Indicar pasillo mecánico (cinta transportadora) en recorridos. | `PathwayRow` (recorrido tipo moving sidewalk) |
| `moon.zzz.fill` | Luna con zzz | Indicar que los equipos (ascensores/escaleras) están apagados por cierre nocturno. | `EquipmentStatusSection` (cierre nocturno Metro Sevilla) |

### UI general

| SF Symbol | Qué es | Para qué se usa |
|-----------|--------|-----------------|
| `exclamationmark.triangle.fill` | Triángulo de alerta | Alertas de servicio, retrasos, PMR warning |
| `xmark` | Cruz | Superpuesto sobre `figure.roll` para indicar "no accesible" |
| `location.fill` / `location.slash` | Pin de ubicación | Posición del tren, ubicación del usuario |
| `star.fill` / `star` | Estrella | Favoritos (llena=favorito, vacía=no) |
| `clock` / `clock.fill` | Reloj | Horarios, próximas salidas |
| `chevron.right` / `chevron.up` / `chevron.down` | Flechas | Navegación, expandir/contraer secciones |
| `icloud.slash` | iCloud tachado | Indicar que los datos son offline (sin conexión) |
| `mappin.circle` | Pin de mapa | Punto de encuentro del servicio Acerca PMR |

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

**Licencia**: Se describe como "dominio público" (US Government work, 1974). **Marco legal pendiente de verificar** para distribución en App Store — ver KNOWN_ISSUES.md.

### ISO 7001 (Wikimedia Commons)

Carpeta: `iso_7001_wikimedia_svg/`

191 SVGs descargados de https://commons.wikimedia.org/wiki/Category:ISO_7001_icons (todas las subcategorías). Recreaciones comunitarias de los símbolos ISO 7001:2023.

Categorías incluidas: Accessibility, Behaviour of the public, Commercial facilities, Public facilities, Sporting activities, Tourism/culture/heritage, Transportation facilities, Diagrams.

**Licencia de los SVGs en Wikimedia**: cada archivo tiene su propia licencia (generalmente CC0 o CC BY-SA). **Sin embargo**, los símbolos ISO 7001 originales son copyright de ISO (~$30/símbolo). Estas recreaciones en Wikimedia son trabajos derivados. **Marco legal pendiente de verificar** para uso en App Store.

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
| `ISO_7001_PI_TF_012.svg` | Funicular |
| `ISO_7001_PI_TF_014.svg` | Parking |
| `ISO_7001_PI_TF_024.svg` | Asientos prioritarios (condiciones médicas) |
| `ISO_7001_PI_TF_040.svg` | Embarque bus |
| `ISO_7001_PI_TF_044.svg` | Carga vehículo eléctrico |

### Otras fuentes pendientes de evaluar

| Fuente | Licencia | URL | Estado |
|--------|----------|-----|--------|
| Temaki | CC0 | https://github.com/rapideditor/temaki | Pendiente. Tiene subway, tram, train, gondola_lift, elevator |
| Maki (Mapbox) | CC0 | https://github.com/mapbox/maki | Pendiente. Tiene rail, rail-metro, rail-light, bus |
| Material Design Icons | Apache 2.0 | https://fonts.google.com/icons | Pendiente. Tiene train, tram, subway, bus, elevator, escalator |
| Accesibiliconos | CC BY-SA 4.0 | https://accesibiliconos.org/ | Pendiente. 52 pictogramas accesibilidad |
| JIS Z8210 (equiv. japonés ISO 7001) | Revisar | https://github.com/cat-in-136/JISZ8210_Symbols_SVG | Pendiente |
| SBB Picto Library (ferrocarriles suizos) | Revisar | https://github.com/sbb-design-systems/picto-library | Pendiente |
| ISO 7001 | Copyright ISO (~$30/símbolo) | https://www.iso.org/standard/77442.html | NO usar sin licencia |

## Licencias

- **AIGA/DOT Symbol Signs**: Descrito como dominio público (US Government work, 1974). **Marco legal pendiente de verificar para distribución en App Store.**
- **StairClimbingSymbol**: Fuente por determinar. Revisar licencia antes de publicar.
- **SF Symbols**: Incluidos con iOS/watchOS. Uso permitido en apps de Apple.
- **ISO 7001**: Copyright de ISO. NO usar sin licencia. ~$30/símbolo o suscripción anual.

## Símbolos que NO tenemos

| Concepto | Estado |
|----------|--------|
| Funicular | Sin icono. Candidatos: Temaki `gondola_lift` (CC0), ISO 7001 PI TF 012 |
| Teleférico | Sin icono. Candidatos: Temaki `gondola_lift` o `chairlift` (CC0), ISO 7001 PI TF 011 |
| Metro (pictograma propio) | Usamos `tram.fill` genérico. No hay pictograma diferenciado |
| Ferry | Sin icono. Candidatos: ISO 7001 PI TF 004, Temaki `ferry` (CC0) |

## Bugs / datos de la API sin símbolo

### `corBus` — correspondencia bus no se muestra

El campo `corBus` existe en el modelo `Stop` y se decodifica de la API, pero en `StopDetailView` los badges de correspondencia bus **nunca se añaden** a `allBadges`. El `TransportKind.bus` existe en el enum pero no se procesa. Necesita implementación + icono `bus.fill`.

### `routeType` (GTFS) — decodificado pero no usado

`RouteResponse.routeType: Int` se decodifica de la API pero no se usa para nada visual ni lógico. Valores GTFS estándar:

| Valor | Tipo | Icono que podría usar |
|-------|------|----------------------|
| 0 | Tram/Streetcar | `tram` / `lightrail.fill` |
| 1 | Subway/Metro | `tram.tunnel.fill` |
| 2 | Rail (cercanías, regional) | `train.side.front.car` |
| 3 | Bus | `bus.fill` |
| 4 | Ferry | — (sin icono) |
| 5 | Cable tram | — (sin icono) |
| 6 | Gondola/aerial | — (sin icono) |
| 7 | Funicular | — (sin icono) |
| 11 | Trolleybus | `bus.fill` |
| 12 | Monorail | — (sin icono) |

Actualmente el tipo de transporte se determina por prefijo del stop ID (`METRO_*`, `RENFE_C_*`, etc.), no por `routeType`. Podría usarse `routeType` como fuente de verdad para asignar iconos automáticamente.

## Pendiente (KNOWN_ISSUES.md)

- **Marco legal AIGA**: verificar si "dominio público" aplica a distribución en App Store
- Revisar licencia de StairClimbingSymbol
- Evaluar fuentes adicionales (Temaki, Maki, Material Design, Accesibiliconos)
- Considerar convertir EPS relevantes a SVG para imagesets
- Implementar badges de correspondencia bus (`corBus`)
- Evaluar uso de `routeType` para asignación automática de iconos
