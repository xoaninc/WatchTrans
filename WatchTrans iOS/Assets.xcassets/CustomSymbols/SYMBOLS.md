# Custom Symbols Reference

Pictogramas custom usados en WatchTrans. Todos se renderizan con `.renderingMode(.template)` para tinting.

## Assets actuales

### AIGA/DOT (Dominio público)

Fuente: https://commons.wikimedia.org/wiki/Category:AIGA_symbol_signs

| Asset | SVG original | Uso en la app |
|-------|-------------|---------------|
| `ElevatorSymbol` | `Aiga_elevator.svg` | EquipmentStatusSection (estado RT ascensores), AccessRow accesos accesibles (Metro Sevilla) |
| `EscalatorSymbol` | `Aiga_escalator.svg` | EquipmentStatusSection (escaleras mecánicas sin dirección), PathwayRow pathways |
| `EscalatorUpSymbol` | `Aiga_escalator_up.svg` | EquipmentStatusSection (escalera mecánica subida) |
| `EscalatorDownSymbol` | `Aiga_escalator_down.svg` | EquipmentStatusSection (escalera mecánica bajada) |
| `StairsSymbol` | `Aiga_stairs.svg` | PathwayRow (recorridos con escaleras normales) |

### Otros (revisar licencia)

| Asset | SVG original | Uso en la app |
|-------|-------------|---------------|
| `StairClimbingSymbol` | `stair-climbing-icon.svg` | AccessRow accesos no accesibles (escaleras) |

## SF Symbols usados (Apple, incluidos con iOS)

### Transporte

| SF Symbol | Uso |
|-----------|-----|
| `tram.fill` | Icono genérico de transporte (ArrivalRow, mapas, widgets, anotaciones, settings) |
| `tram.tunnel.fill` | Badge "Metro" en StopDetailView |
| `lightrail.fill` | Badge "Tram" en StopDetailView |
| `train.side.front.car` | Badge "Vía" en TrainDetailView, Journey planner (cercanías) |
| `bus.fill` | Badge "Bus", servicio alternativo en ArrivalRowView |
| `tram` | Journey planner (tranvía, sin relleno) |

### Accesibilidad

| SF Symbol | Uso |
|-----------|-----|
| `figure.roll` | Accesibilidad silla de ruedas (verde=accesible, rojo+xmark=no accesible) |
| `figure.walk` | Recorridos a pie (PathwayRow, Journey planner) |
| `figure.stairs` | — (sustituido por `StairsSymbol` AIGA en pathways) |
| `bicycle` | Bicicletas permitidas (ArrivalRowView), Parking Bici (StopDetailView) |

### Equipamiento/Servicios

| SF Symbol | Uso |
|-----------|-----|
| `door.left.hand.open` | Accesos sin ascensor (StationInteriorSection), entrada journey planner, vestíbulo Acerca |
| `door.right.hand.open` | Salida journey planner |
| `creditcard` | PathwayRow (torniquetes/fare gate) |
| `arrow.left.arrow.right` | PathwayRow (pasillo mecánico/moving sidewalk) |
| `moon.zzz.fill` | Cierre nocturno equipos (EquipmentStatusSection) |

### UI general

| SF Symbol | Uso |
|-----------|-----|
| `exclamationmark.triangle.fill` | Alertas, retrasos, PMR warning |
| `xmark` | Superpuesto sobre figure.roll para "no accesible" |
| `location.fill` / `location.slash` | Posición del tren, ubicación usuario |
| `star.fill` / `star` | Favoritos |
| `clock` / `clock.fill` | Horarios, salidas |
| `chevron.right` / `chevron.up` / `chevron.down` | Navegación, expandir/contraer |
| `icloud.slash` | Datos offline |
| `mappin.circle` | Punto de encuentro (Acerca PMR) |

## Licencias

- **AIGA/DOT Symbol Signs**: Dominio público (US Government work, 1974). Sin restricciones de uso.
- **StairClimbingSymbol**: Fuente por determinar. Revisar licencia antes de publicar.
- **SF Symbols**: Incluidos con iOS/watchOS. Uso permitido en apps de Apple.
- **ISO 7001**: Copyright de ISO. NO usar sin licencia. ~$30/símbolo o suscripción anual.

## Pendiente (KNOWN_ISSUES.md)

- Revisar licencia de StairClimbingSymbol
- Revisar atribución AIGA para App Store
- Considerar añadir símbolos AIGA para: bus, taxi, tren (rail transportation)
- Evaluar Temaki (CC0) para metro/tranvía/funicular si se necesitan
