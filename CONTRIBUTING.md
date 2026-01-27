# Guia de Contribucion

Gracias por tu interes en contribuir a WatchTrans. Esta guia te ayudara a empezar.

## Codigo de Conducta

Este proyecto sigue un codigo de conducta basico: se respetuoso, constructivo y profesional en todas las interacciones.

## Como Contribuir

### Reportar Bugs

Si encuentras un bug, por favor abre un issue incluyendo:

1. **Descripcion clara** del problema
2. **Pasos para reproducir** el error
3. **Comportamiento esperado** vs comportamiento actual
4. **Version de iOS/watchOS** donde ocurre
5. **Capturas de pantalla** si aplica

### Sugerir Mejoras

Para sugerir nuevas funcionalidades:

1. Verifica que no exista ya un issue similar
2. Describe la funcionalidad propuesta
3. Explica el caso de uso y beneficios
4. Si es posible, incluye mockups o ejemplos

### Pull Requests

1. **Fork** el repositorio
2. **Crea una rama** desde `main`:
   ```bash
   git checkout -b feature/mi-nueva-funcionalidad
   ```
3. **Realiza tus cambios** siguiendo las guias de estilo
4. **Escribe tests** si aplica
5. **Commit** con mensajes descriptivos:
   ```bash
   git commit -m "Add: soporte para nueva red de transporte"
   ```
6. **Push** a tu fork:
   ```bash
   git push origin feature/mi-nueva-funcionalidad
   ```
7. **Abre un Pull Request** describiendo tus cambios

## Guias de Estilo

### Swift

- Sigue las [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Usa `camelCase` para variables y funciones
- Usa `PascalCase` para tipos y protocolos
- Documenta funciones publicas con comentarios `///`
- Maximo 120 caracteres por linea

### Estructura de Archivos

```
WatchTrans/
├── Shared/           # Codigo compartido entre targets
├── WatchTrans iOS/   # Codigo especifico de iOS
├── WatchTrans Watch App/  # Codigo especifico de watchOS
└── WatchTransWidget/ # Widget
```

### Commits

Usa prefijos descriptivos:

- `Add:` Nueva funcionalidad
- `Fix:` Correccion de bug
- `Update:` Mejora de funcionalidad existente
- `Refactor:` Cambios de estructura sin cambio de funcionalidad
- `Docs:` Cambios en documentacion
- `Style:` Cambios de formato (sin cambios de codigo)
- `Test:` Añadir o modificar tests

### SwiftUI

- Extrae componentes reutilizables a archivos separados
- Usa `@State` para estado local, `@Observable` para modelos
- Prefiere `VStack`/`HStack`/`ZStack` sobre `GeometryReader` cuando sea posible
- Usa modificadores de vista en orden logico

## Arquitectura

### Servicios

- `DataService`: Gestion de datos y cache
- `LocationService`: Ubicacion del usuario
- `GTFSRealtimeService`: Comunicacion con API
- `FavoritesManager`: Persistencia de favoritos
- `FrequentStopsService`: Deteccion de paradas frecuentes
- `MapLauncher`: Abrir ubicaciones en apps de mapas externas

> Nota: El calculo de rutas se hace en la API, no en el cliente.

### Modelos

Los modelos estan en `Shared/Models/` y son compartidos entre iOS y watchOS.

### API

La app consume `https://redcercanias.com/api/v1/gtfs`. Consulta `API_STATUS.md` para el estado actual de los endpoints.

## Desarrollo Local

### Requisitos

- macOS 14.0+
- Xcode 15.0+
- iOS 17.0+ / watchOS 10.0+

### Setup

```bash
git clone https://github.com/tu-usuario/WatchTrans.git
cd WatchTrans
open WatchTrans.xcodeproj
```

### Testing

Ejecuta los tests desde Xcode:
- `Cmd + U` para ejecutar todos los tests
- Selecciona el target apropiado (iOS o Watch)

## Preguntas

Si tienes dudas, abre un issue con la etiqueta `question`.

---

Gracias por contribuir a WatchTrans!
