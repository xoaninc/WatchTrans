# WatchTrans iOS - Guia de Configuracion en Xcode

## 1. Crear nuevo Target iOS

1. Abre el proyecto `WatchTrans.xcodeproj` en Xcode
2. Ve a **File > New > Target...**
3. Selecciona **iOS > App**
4. Configura:
   - **Product Name**: `WatchTrans iOS`
   - **Team**: Tu equipo de desarrollo
   - **Organization Identifier**: `juan` (o tu identificador)
   - **Bundle Identifier**: `juan.WatchTrans.ios`
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Storage**: SwiftData
5. Click **Finish**

## 2. Configurar App Group

Para compartir datos entre iOS y watchOS:

1. Selecciona el target **WatchTrans iOS**
2. Ve a **Signing & Capabilities**
3. Click **+ Capability**
4. Selecciona **App Groups**
5. Agrega el grupo: `group.juan.WatchTrans`

## 3. Agregar archivos al Target iOS

### 3.1 Archivos Shared (reutilizables)

Arrastra estos archivos al target iOS y marca **"Add to targets: WatchTrans iOS"**:

**Shared/Models/**
- `Arrival.swift`
- `Line.swift`
- `Stop.swift`
- `TransportType.swift`
- `Favorite.swift`

**Shared/Services/**
- `DataService.swift`
- `LocationService.swift`
- `FavoritesManager.swift`
- `APIConfiguration.swift`
- `SharedStorage.swift`

**Shared/Services/Network/**
- `NetworkService.swift`
- `NetworkMonitor.swift`
- `NetworkError.swift`

**Shared/Services/GTFSRT/**
- `GTFSRealtimeService.swift`
- `GTFSRealtimeMapper.swift`
- `RenfeServerModels.swift`

**Shared/Extensions/**
- `Color+Hex.swift`

### 3.2 Archivos iOS (nuevos)

Arrastra estos archivos al target iOS:

**WatchTrans iOS/**
- `WatchTransApp.swift`

**WatchTrans iOS/Views/**
- `MainTabView.swift`
- `SettingsView.swift`

**WatchTrans iOS/Views/Home/**
- `HomeView.swift`

**WatchTrans iOS/Views/Search/**
- `SearchView.swift`

**WatchTrans iOS/Views/Stop/**
- `StopDetailView.swift`

**WatchTrans iOS/Views/Lines/**
- `LinesListView.swift`
- `LineDetailView.swift`

**WatchTrans iOS/Components/**
- `LineBadgeView.swift`
- `ArrivalRowView.swift`

## 4. Configurar Info.plist

Agrega las siguientes claves al `Info.plist` del target iOS:

```xml
<!-- Permisos de ubicacion -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>WatchTrans necesita tu ubicacion para mostrar las paradas cercanas.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>WatchTrans usa tu ubicacion para mostrarte las paradas de transporte mas cercanas.</string>

<!-- URL Scheme para deep links (opcional) -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>watchtrans</string>
        </array>
    </dict>
</array>
```

## 5. Crear Assets Catalog

1. En el target iOS, crea **New File > Asset Catalog**
2. Nombra: `Assets`
3. Agrega:
   - **AppIcon** (1024x1024 para iOS)
   - **AccentColor** (azul #007AFF o similar)
   - Logos de operadores (opcional, se cargan desde API)

## 6. Compilar y Probar

1. Selecciona el scheme **WatchTrans iOS**
2. Selecciona un simulador iOS (iPhone 15 Pro recomendado)
3. Presiona **Cmd+R** para compilar y ejecutar

## 7. Posibles errores y soluciones

### Error: "Cannot find type 'X' in scope"
- Asegurate de que el archivo este agregado al target iOS
- Project Navigator > Selecciona archivo > File Inspector > Target Membership

### Error: "WKInterfaceDevice is only available on watchOS"
- Este codigo es solo para watchOS
- Los archivos iOS no deben tener imports de WatchKit

### Error: "App Group container not found"
- Verifica que el App Group este configurado en ambos targets
- El identificador debe ser exactamente `group.juan.WatchTrans`

## 8. Estructura final del proyecto

```
WatchTrans.xcodeproj
├── Shared/                    # Codigo compartido (ambos targets)
│   ├── Models/
│   ├── Services/
│   └── Extensions/
├── WatchTrans Watch App/      # Target watchOS
│   ├── Views/
│   └── Assets.xcassets
├── WatchTrans iOS/            # Target iOS (nuevo)
│   ├── Views/
│   ├── Components/
│   └── Assets.xcassets
└── WatchTransWidget/          # Widget (existente)
```

## 9. Target Membership Reference

| Archivo | Watch App | iOS | Widget |
|---------|:---------:|:---:|:------:|
| Shared/Models/* | ✓ | ✓ | |
| Shared/Services/* | ✓ | ✓ | |
| Shared/Extensions/* | ✓ | ✓ | ✓ |
| WatchTrans Watch App/Views/* | ✓ | | |
| WatchTrans iOS/Views/* | | ✓ | |
| WatchTransWidget/* | | | ✓ |

---

*Documento creado: Enero 2026*
