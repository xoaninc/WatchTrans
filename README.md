# WatchTrans

Aplicación de transporte público para Apple Watch e iOS que muestra horarios en tiempo real de Cercanías, Metro, Metro Ligero y Tranvía en España.

## Características

### General
- Horarios en tiempo real usando GTFS-RT
- Soporte para múltiples redes de transporte (Cercanías, Metro Madrid, Metro Ligero, Rodalies, etc.)
- Detección automática de ubicación para mostrar líneas cercanas
- Favoritos sincronizados entre dispositivos
- Alertas de servicio en tiempo real
- **Detección de servicios suspendidos** (nuevo)

### iOS App
- Vista principal con paradas cercanas
- Búsqueda de paradas
- Lista de líneas por red de transporte
- Detalle de línea con todas las paradas
- Detalle de parada con salidas en tiempo real
- Alertas expandibles
- Banner de servicio suspendido

### Watch App
- Vista compacta optimizada para Apple Watch
- Navegación rápida entre líneas y paradas
- Tarjetas de salida con información de retraso
- Posición del tren en tiempo real
- Alertas con navegación a página completa

## Estructura del Proyecto

```
WatchTrans/
├── Shared/                          # Código compartido
│   ├── Models/                      # Modelos de datos
│   │   ├── Arrival.swift
│   │   ├── Favorite.swift
│   │   ├── Line.swift
│   │   ├── Stop.swift
│   │   └── TransportType.swift
│   ├── Services/                    # Servicios
│   │   ├── DataService.swift
│   │   ├── FavoritesManager.swift
│   │   ├── LocationService.swift
│   │   ├── GTFSRT/
│   │   │   ├── GTFSRealtimeService.swift
│   │   │   ├── GTFSRealtimeMapper.swift
│   │   │   └── RenfeServerModels.swift
│   │   └── Network/
│   │       ├── NetworkService.swift
│   │       ├── NetworkMonitor.swift
│   │       └── NetworkError.swift
│   └── Extensions/
│       └── Color+Hex.swift
├── WatchTrans iOS/                  # App iOS
│   ├── Views/
│   │   ├── Home/
│   │   ├── Lines/
│   │   ├── Search/
│   │   └── Stop/
│   └── Shared/                      # Copia local de servicios
├── WatchTrans Watch App/            # App Watch
│   ├── Views/
│   └── Services/                    # Copia local de servicios
└── WatchTransWidget/                # Widget para Watch
```

## API

La app consume la API de [redcercanias.com](https://redcercanias.com):

### Endpoints principales

| Endpoint | Descripción |
|----------|-------------|
| `GET /api/v1/gtfs/networks` | Lista de redes de transporte |
| `GET /api/v1/gtfs/routes` | Lista de líneas |
| `GET /api/v1/gtfs/stops/{stop_id}/departures` | Salidas de una parada |
| `GET /api/v1/gtfs/routes/{route_id}/operating-hours` | Horarios de operación |
| `GET /api/v1/gtfs/realtime/routes/{route_id}/alerts` | Alertas de una línea |

### Detección de servicio suspendido

El endpoint `/operating-hours` ahora incluye campos de suspensión:

```json
{
  "route_id": "RENFE_C9_41",
  "route_short_name": "C9",
  "weekday": null,
  "friday": null,
  "saturday": null,
  "sunday": null,
  "is_suspended": true,
  "suspension_message": "#MadC9 Cercanías Madrid informa: por obras..."
}
```

La app muestra un banner rojo de "Servicio suspendido" cuando `is_suspended: true`.

## Requisitos

- iOS 17.0+
- watchOS 10.0+
- Xcode 15.0+

## Instalación

1. Clonar el repositorio
2. Abrir `WatchTrans.xcodeproj` en Xcode
3. Seleccionar el target deseado (iOS o Watch)
4. Build & Run

## Changelog reciente

### 2026-01-21
- Añadido soporte para servicios suspendidos (`is_suspended`, `suspension_message`)
- Banner rojo de "Servicio suspendido" en LineDetailView
- Struct `OperatingHoursResult` para manejar horarios y suspensión
- Alertas expandibles en iOS
- Página de alertas separada en Watch
- Colores correctos en badges de líneas
- Formato correcto de nombres de línea (C4a, L10b, ML1)

## Licencia

Este proyecto esta licenciado bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para mas detalles.
