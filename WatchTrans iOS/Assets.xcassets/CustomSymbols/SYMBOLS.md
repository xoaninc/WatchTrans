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
| `tram.fill` | Tranvía/tren relleno | Icono genérico de transporte ferroviario. Se usa para todo tipo de servicio ferroviario como icono por defecto. | `ArrivalRowView`, mapas, widgets, anotaciones, settings, `TrainDetailView` |
| `tram.tunnel.fill` | Tren saliendo de túnel | Indicar que la parada es de metro (subterráneo). | `StopDetailView` badge "Metro" |
| `lightrail.fill` | Tren ligero relleno | Indicar que la parada es de tranvía/tram. | `StopDetailView` badge "Tram" |
| `tram` | Tranvía sin relleno | Modo de transporte tranvía en el planificador de rutas. | `Journey` model (modo tranvía) |
| `train.side.front.car` | Tren visto de lado | Indicar vía/andén de un tren. Modo de transporte cercanías en el planificador. | `TrainDetailView` badge "Vía", `Journey` model (modo cercanías) |
| `bus.fill` | Autobús relleno | Indicar parada de bus o servicio alternativo por autobús. | `StopDetailView` badge "Bus", `ArrivalRowView` (servicio alternativo) |

### Accesibilidad

| SF Symbol | Qué es | Para qué se usa | Dónde en la app |
|-----------|--------|-----------------|-----------------|
| `figure.roll` | Persona en silla de ruedas | Indicar accesibilidad. Verde = accesible. Rojo + xmark superpuesto = no accesible. | `ArrivalRowView` (por tren), `TrainDetailView`, `StopDetailView` (por parada), `EquipmentStatusSection` (header), `StationInteriorSection` (accesos no accesibles) |
| `figure.walk` | Persona andando | Indicar recorrido a pie entre estaciones o dentro de la estación. | `PathwayRow` (recorrido tipo walkway), `JourneyPlannerView` (segmento andando) |
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

## Licencias

- **AIGA/DOT Symbol Signs**: Dominio público (US Government work, 1974). Sin restricciones de uso.
- **StairClimbingSymbol**: Fuente por determinar. Revisar licencia antes de publicar.
- **SF Symbols**: Incluidos con iOS/watchOS. Uso permitido en apps de Apple.
- **ISO 7001**: Copyright de ISO. NO usar sin licencia. ~$30/símbolo o suscripción anual.

## Símbolos que NO tenemos

| Concepto | Estado |
|----------|--------|
| Funicular | Sin icono. No hay AIGA ni SF Symbol. Candidatos: Temaki `gondola_lift` (CC0) |
| Teleférico | Sin icono. Candidato: Temaki `gondola_lift` o `chairlift` (CC0) |
| Metro (pictograma propio) | Usamos `tram.fill` genérico. No hay pictograma diferenciado |

## Pendiente (KNOWN_ISSUES.md)

- Revisar licencia de StairClimbingSymbol
- Revisar atribución AIGA para App Store
- Considerar añadir símbolos AIGA para: bus, taxi, tren (rail transportation)
- Evaluar Temaki (CC0) para metro/tranvía/funicular si se necesitan
