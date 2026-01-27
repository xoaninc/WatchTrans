# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.

El formato esta basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/),
y este proyecto sigue [Semantic Versioning](https://semver.org/lang/es/).

## [Unreleased]

### Added
- Animacion 3D mejorada del planificador de rutas con shapes reales de la API
- Pausas entre segmentos y en estaciones intermedias
- Velocidad de animacion moderada para mejor visualizacion del recorrido

### Changed
- RoutingService ahora carga los polylines reales de cada linea
- Interpolacion de puntos para animaciones mas suaves

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
