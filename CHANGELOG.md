# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.

El formato esta basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/),
y este proyecto sigue [Semantic Versioning](https://semver.org/lang/es/).

## [Unreleased]

### Added
- **Modo Desarrollador oculto**: Tap 7x en version para activar
- **KeychainService**: Almacenamiento seguro de tokens
- **AdminService**: Funcion para recargar GTFS en servidor (POST /admin/reload-gtfs)
- **Alertas de servicio en planificador de viajes**: RouteAlertsView muestra avisos de la API RAPTOR
- **Siri Shortcut "Plan Route"**: "¿Como llego de X a Y?" usando RAPTOR con ?compact=true
- Siri Shortcuts para "Proximo tren en [parada]"
- Deteccion automatica de paradas frecuentes basada en patrones de uso
- Seccion "Frecuentes" en Home con badge de patron (ej: "~08:00 L-V")
- Abrir ubicaciones en Apple Maps, Google Maps, Citymapper o Waze
- Info.plist con LSApplicationQueriesSchemes para detectar apps instaladas
- ROADMAP.md unificado con todas las tareas pendientes
- **Debug logs exhaustivos** en JourneyPlannerView, DataService y GTFSRealtimeService

### Changed
- Migracion de calculo de rutas del cliente a la API (eliminado RoutingService.swift)
- GTFSRealtimeService.fetchRoutePlan ahora soporta parametro `compact: Bool`
- Documentacion reorganizada y consolidada

### Removed
- RoutingService.swift (~530 lineas) - routing ahora se hace en servidor
- API_CHANGES_v2.md (contenido movido a ROADMAP.md)

## [1.1.1] - 2026-01-28

### Added
- **RouteAlertsView**: Componente expandible para mostrar alertas de servicio en JourneyPlannerView
- **PlanRouteIntent.swift**: Siri Shortcut para planificar rutas con comandos de voz
- Soporte para `?compact=true` en endpoint route-planner (respuestas <5KB para Widget/Siri)
- Debug logs detallados con timestamps y estructura clara para analisis

### Changed
- JourneyPlannerView ahora muestra alertas de la API automaticamente
- AppShortcuts incluye frases en espanol e ingles para "Plan Route"
- GTFSRealtimeService registra tiempo de respuesta de API y detalles de journeys

## [1.1.0] - 2026-01-26

### Added
- Planificador de viajes con vista previa 3D animada
- Mapa de recorrido con soporte de polylines para lineas de transporte
- Campo `to_transport_types` en modelo CorrespondenceInfo
- Soporte para endpoints de plataformas y correspondencias
- Filtrado de busqueda de paradas por provincia/region actual

### Changed
- Migracion de API de renfeapp.fly.dev a redcercanias.com

## [1.0.0] - 2026-01-21

### Added
- Soporte para servicios suspendidos (`is_suspended`, `suspension_message`)
- Banner rojo de "Servicio suspendido" en LineDetailView
- Struct `OperatingHoursResult` para manejar horarios y suspension
- Alertas expandibles en iOS
- Pagina de alertas separada en Watch
- Deteccion automatica de ubicacion para mostrar lineas cercanas
- Favoritos sincronizados entre dispositivos
- Alertas de servicio en tiempo real

### Fixed
- Colores correctos en badges de lineas
- Formato correcto de nombres de linea (C4a, L10b, ML1)

## [0.9.0] - 2026-01-15

### Added
- App iOS con vista principal de paradas cercanas
- Busqueda de paradas
- Lista de lineas por red de transporte
- Detalle de linea con todas las paradas
- Detalle de parada con salidas en tiempo real

### Added (Watch)
- Vista compacta optimizada para Apple Watch
- Navegacion rapida entre lineas y paradas
- Tarjetas de salida con informacion de retraso
- Posicion del tren en tiempo real
- Alertas con navegacion a pagina completa

## [0.1.0] - 2026-01-01

### Added
- Estructura inicial del proyecto
- Modelos de datos (Arrival, Favorite, Line, Stop, TransportType)
- Servicios compartidos (DataService, FavoritesManager, LocationService)
- Integracion con GTFS-RT
- Soporte para multiples redes de transporte:
  - Cercanias RENFE
  - Metro Madrid
  - Metro Ligero Madrid
  - Rodalies Catalunya
  - FGC
  - Euskotren
  - Metro Bilbao
  - TMB Barcelona
  - Metro Sevilla
  - Tranvia
