# Swift Resources & Tools

Recursos, tutoriales y herramientas útiles para el desarrollo de WatchTrans.

---

## Hot Reloading — InjectionIII + Inject

**Para qué sirve:** Ver cambios en views SwiftUI en tiempo real sin recompilar la app. Evita depender de SwiftUI Previews (que fallan constantemente). Saves de un archivo → la app se actualiza al instante.

**Fuente:** https://medium.gonzalofuentes.com/hot-reloading-in-swiftui-made-simple-95f31900f535

**Componentes:**
- **InjectionIII** — App macOS que inyecta código en tiempo de ejecución. Se descarga de https://github.com/nicklama/InjectionIII
- **Inject** — Paquete Swift que conecta tu app con InjectionIII. Repo: https://github.com/krzysztofzablocki/Inject

**Setup:**
1. Instalar InjectionIII y ejecutarlo
2. En InjectionIII menu bar → Add Directory → seleccionar carpeta del proyecto
3. En Xcode: File → Add Packages → `https://github.com/krzysztofzablocki/Inject`
4. Build Settings → Other Linker Flags → añadir `-Xlinker` y `-interposable` (en líneas separadas, **solo Debug**)
5. En cada view donde quieras hot reload:
```swift
import Inject

struct MiView: View {
    @ObserveInjection var inject

    var body: some View {
        VStack { ... }
        .enableInjection()
    }
}
```

**Limitaciones:**
- ⚠️ Puede no funcionar si el proyecto está en Documents o Desktop
- Solo funciona para cambios en views SwiftUI
- Cambios en modelos, services o lógica necesitan recompilación completa
- El código de Inject no se compila en Release (no afecta producción)

**Funciona con:** Xcode, VSCode + SweetPad, Cursor + SweetPad

---

## User Location con CLLocationManager

**Para qué sirve:** Obtener la ubicación GPS del usuario en SwiftUI. Es el patrón estándar de Apple para location services.

**Fuente:** https://medium.gonzalofuentes.com/obtaining-user-location-with-swift-and-swiftui-a-step-by-step-guide-3987ba401782

**Patrón:**
1. Añadir `Privacy - Location When In Use Usage Description` en Info.plist
2. Crear ViewModel como `ObservableObject` + `CLLocationManagerDelegate`
3. `requestWhenInUseAuthorization()` para pedir permiso
4. `startUpdatingLocation()` para empezar a recibir coordenadas
5. Publicar `userLocation: CLLocationCoordinate2D?` con `@Published`
6. Manejar `didChangeAuthorization` para reaccionar a cambios de permiso

**Estado en WatchTrans:** Ya implementado en `LocationService.swift`. No necesita cambios.

---

## SweetPad — Swift desde VSCode/Cursor

**Para qué sirve:** Compilar, ejecutar y depurar apps Swift/SwiftUI directamente desde VSCode o Cursor, sin abrir Xcode. Útil si prefieres un editor más ligero.

**Cómo:** Extensión de VSCode que permite seleccionar scheme, simulador, y ejecutar desde la barra inferior del editor.

**URL:** VSCode Marketplace → buscar "SweetPad"

---

## Liquid Glass — iOS 26

**Para qué sirve:** Nuevo lenguaje de diseño de Apple para iOS 26. Efecto de cristal líquido/translúcido en componentes UI. Todos los controles nativos (TabView, NavigationBar, etc.) lo adoptan automáticamente, pero se puede personalizar.

**Fuente:** https://github.com/GonzaloFuentes28/LiquidGlassCheatsheet (168 stars)

**Relevancia para WatchTrans:** Cuando migremos a iOS 26 como target mínimo, la app adoptará Liquid Glass automáticamente. El cheatsheet tiene ejemplos de personalización.

---

## AppMRR — Leaderboard de Revenue con RevenueCat

**Para qué sirve:** Plataforma open source que muestra un leaderboard transparente de ingresos de apps iOS. Los developers comparten voluntariamente sus métricas de RevenueCat (MRR y revenue 28 días). Referencia para integrar RevenueCat en WatchTrans cuando implementemos funcionalidades de pago.

**Fuente:** https://github.com/GonzaloFuentes28/AppMRR (MIT)

**Stack:** Astro + TypeScript + Supabase/PostgreSQL + Vercel

**Cómo integra RevenueCat:**
- Usa RevenueCat API v2 con API keys de solo lectura
- Keys encriptadas con AES-256-GCM + PBKDF2 (100k iteraciones)
- Cron job diario a medianoche UTC descifra keys, consulta RevenueCat, actualiza métricas
- Rate limiting: 3 submissions/hora/IP

**Archivos clave:**
- `/src/lib/revenuecat.ts` — Cliente de RevenueCat API
- `/src/lib/encryption.ts` — Encriptación AES-256-GCM
- `/src/pages/api/add-startup` — Validación de submissions

**Relevancia para WatchTrans:** Ejemplo real de integración con RevenueCat para métricas de revenue. Cuando implementemos suscripciones/compras in-app, este repo muestra cómo funciona la API de RevenueCat.

---

## dimeApp — Expense Tracker iOS (referencia de diseño)

**Para qué sirve:** App de finanzas personales 100% gratuita, hecha con SwiftUI siguiendo las guías de diseño de Apple. Buena referencia de patrones de UI, widgets, iCloud sync, y biometría.

**Fuente:** https://github.com/GonzaloFuentes28/dimeApp (fork, GPL v3)

**Features relevantes para WatchTrans:**
- **iCloud Sync** — Sincronización entre dispositivos (nosotros usamos iCloudSyncService)
- **Widgets Home/Lock screen** — Implementación de widgets (nosotros tenemos WatchTransWidget)
- **Quick Actions** — Acciones rápidas desde home screen
- **Biometría** — Autenticación con Face ID/Touch ID
- **Dark mode** — Soporte completo
- **Modular:** BudgetIntent, BudgetIntentUI, ExpenditureWidget — separación negocio/presentación

**Dependencias interesantes:**
- SwiftUI Introspect — Acceder a UIKit desde SwiftUI
- CloudKitSyncMonitor — Monitorear estado de sync iCloud
- ConfettiSwiftUI — Animaciones de confetti

**Relevancia para WatchTrans:** Referencia de cómo estructurar widgets, iCloud sync, y quick actions en una app SwiftUI real.

---

## SwiftUI Agent Skill para Claude Code

**Para qué sirve:** Skill que hace que Claude Code escriba mejor código SwiftUI — evita errores comunes de LLMs (APIs deprecated, botones invisibles a VoiceOver, problemas de performance). Creado por Paul Hudson (Hacking with Swift).

**Fuente:** https://github.com/twostraws/SwiftUI-Agent-Skill (3.1K stars, MIT)

**Instalación:**
```bash
npx skills add https://github.com/twostraws/swiftui-agent-skill --skill swiftui-pro
```

**Uso:** `/swiftui-pro` en Claude Code. Soporta también Codex, Gemini, Cursor.

**Skills relacionados del mismo autor:** SwiftData Pro, Swift Concurrency Pro, Swift Testing Pro.

---

## App Store Connect CLI

**Para qué sirve:** CLI para automatizar TODO el ciclo de publicación en App Store sin abrir la web. TestFlight, builds, submissions, screenshots, suscripciones, analytics.

**Fuente:** https://github.com/rudrankriyam/App-Store-Connect-CLI (3.4K stars, MIT, Go)

**Instalación:** `brew install asc`

**Ejemplos:**
```bash
asc apps list                                    # Listar apps
asc testflight crashes list --app "ID"           # Ver crashes TestFlight
asc builds upload --app "ID" --ipa "path.ipa"   # Subir build
asc release run --app "ID" --version "1.2.3"    # Release completo
```

**Relevancia:** Cuando publiquemos WatchTrans en App Store, automatiza TestFlight y submissions desde terminal/CI.

---

## Votice SDK — Feedback y votaciones in-app

**Para qué sirve:** SDK nativo Swift para recoger sugerencias, feedback y votos dentro de la app. Sin Firebase, privacy-first, HMAC auth.

**Fuente:** https://github.com/ArtCC/votice-sdk (12 stars, MIT)

**Instalación:** SPM → `https://github.com/artcc/votice-sdk`

**Uso:**
```swift
try Votice.configure(apiKey: "key", apiSecret: "secret", appId: "id")
Votice.feedbackSheet(isPresented: $showFeedback)
```

**Features:** Temas personalizables, fuentes custom, localización, usuarios premium, comentarios.

**Relevancia:** Si queremos que los usuarios sugieran features o reporten bugs dentro de WatchTrans.

---

## SwiftUI-SFSymbols — Type-safe SF Symbols

**Para qué sirve:** Elimina string literals para SF Symbols. Validación en compile-time en vez de runtime.

**Fuente:** https://github.com/Sedlacek-Solutions/SwiftUI-SFSymbols (58 stars, MIT)

**Uso:**
```swift
extension SFSymbol {
    static let star = SFSymbol(rawValue: "star")
}
Image(symbol: .star)  // En vez de Image(systemName: "star")
```

**Relevancia:** Ahora que hemos migrado a custom assets, menos útil. Pero para los SF Symbols que mantuvimos (clock, star, chevron, etc.) podría evitar typos.

---

## SwiftUI-Ratings — Pantalla "Valora la app"

**Para qué sirve:** Pantalla elegante y personalizable para pedir al usuario que valore la app en el App Store. Muestra ratings actuales y reviews.

**Fuente:** https://github.com/Sedlacek-Solutions/SwiftUI-Ratings (226 stars, MIT)

**Uso:**
```swift
RatingRequestScreen(
    appId: "APP_ID",
    appRatingProvider: provider,
    primaryButtonAction: { /* rate */ },
    secondaryButtonAction: { /* later */ }
)
```

**Relevancia:** Para cuando WatchTrans esté en App Store — pedir valoraciones a los usuarios.

---

## SystemNotification — Notificaciones estilo iOS nativo

**Para qué sirve:** Mostrar notificaciones tipo "Silent Mode On" o "AirPods Connected" — la burbuja que baja desde arriba. Nativo SwiftUI.

**Fuente:** https://github.com/danielsaidi/SystemNotification (891 stars, MIT)

**Uso:**
```swift
.systemNotification(isActive: $isActive) {
    SystemNotificationMessage(
        icon: Text("👍"),
        title: "Favorito añadido",
        text: "Sol - Cercanías Madrid"
    )
}
```

**Relevancia:** Para feedback visual al añadir favoritos, activar/desactivar filtros, etc. Más elegante que un toast custom.

---

## IsoCountryCodes — Códigos ISO de países

**Para qué sirve:** Lookup de países por código ISO (alpha-2, alpha-3, numérico). Devuelve nombre, moneda, código telefónico, continente, emoji bandera.

**Fuente:** https://github.com/funky-monkey/IsoCountryCodes (143 stars, licencia permisiva)

**Uso:**
```swift
IsoCountryCodes.find(key: "ES").name       // "Spain"
IsoCountryCodes.find(key: "ES").currency   // "EUR"
IsoCountryCodes.find(key: "ES").flag       // 🇪🇸
IsoCountryCodes.searchByCurrency("EUR")    // 31 países
```

**Relevancia:** Si expandimos WatchTrans a otros países o necesitamos localización por país.

---

---

## Apps y proyectos de transporte (competencia/referencia)

### MadridTransporte — App de transporte público Madrid

**Para qué sirve:** App web/PWA que muestra tiempos reales y localización de vehículos del transporte público de Madrid. Competidor directo / referencia.

**Fuente:** https://github.com/xBaank/MadridTransporte (GPL-3.0)

**Redes:** EMT Madrid (buses), Metro de Madrid, Cercanías Renfe Madrid, buses interurbanos.

**Features:**
- Tiempos de llegada reales (no countdown)
- Localización de buses en mapa
- Favoritos con nombres custom
- Push notifications minuto a minuto
- Alertas de incidencias
- Búsqueda por GPS

**Stack:** Frontend web (PWA) + backend separados (submodules). Android APK disponible.

**Diferencias con WatchTrans:** Es web/PWA, nosotros somos nativos iOS/watchOS. Ellos solo Madrid, nosotros toda España. Su API subyacente "se cae frecuentemente" (según su README). No tiene Apple Watch.

---

### MCP Madrid Public Transport — MCP server para Claude

**Para qué sirve:** Servidor MCP que da ETAs de transporte de Madrid a Claude Desktop. Puedes preguntar "¿cuándo llega el próximo metro a Sol?" y Claude responde con datos reales.

**Fuente:** https://github.com/dieguezz/mcp-madrid-public-transport (TypeScript, 3 stars)

**Redes:** Metro de Madrid, EMT Buses, Renfe Cercanías.

**Cómo obtiene datos:**
- Metro: API oficial de teleindicadores (sin auth)
- EMT: OpenAPI con OAuth (Client ID + Pass Key gratuitos)
- Renfe: GTFS Realtime público (posiciones de vehículos)

**Stack:** TypeScript, Clean Architecture, SQLite para cache GTFS, LRU caching.

**Relevancia:** Referencia de cómo consumir las mismas APIs que usamos nosotros. La API de Metro es la de "teleindicadores" que no conocíamos. El approach de cache GTFS en SQLite puede ser útil para offline.

---

### CRTM-NFC/Mifare-Desfire — Research tarjetas NFC Metro Madrid

**Para qué sirve:** Investigación de seguridad sobre cómo funcionan las tarjetas NFC del transporte público de Madrid (Tarjeta Multi).

**Fuente:** https://github.com/CRTM-NFC/Mifare-Desfire

**Descubrimientos:**
- Tarjetas usan Mifare DESfire EV1 (NXP MF3ICD41)
- 2 aplicaciones (AIDs 0x00 y 0x01), múltiples archivos
- Hasta 14 keys criptográficas por aplicación
- Auth con DES encryption, sessions con JSESSIONID
- Contienen: perfil usuario, info tarifaria, fechas validez, saldo

**Relevancia:** Si algún día queremos leer la tarjeta de transporte con NFC del iPhone para mostrar saldo o títulos de viaje.

---

### cercanias-renfe-android — App histórica Cercanías

**Para qué sirve:** App Android histórica de Cercanías Renfe. Retirada de Google Play en 2012 por queja de Renfe (marca registrada). Tuvo +100K instalaciones.

**Fuente:** https://github.com/jonseg/cercanias-renfe-android (código archivado)

**Cómo obtenía datos:** Web scraping de la web de Renfe vía parser PHP en backend propio.

**Relevancia:** Histórica — ejemplo de los problemas legales de usar la marca Renfe. No mantenido desde 2012.

---

### gtfs-to-geojson — Convertir GTFS a GeoJSON

**Para qué sirve:** Convertir datos GTFS (feeds de transporte) a GeoJSON para mapas interactivos. Genera líneas de rutas + puntos de paradas.

**Fuente:** https://github.com/BlinkTagInc/gtfs-to-geojson

**Instalación:** `npm install gtfs-to-geojson -g`

**Formatos de salida:** Líneas + paradas, polígonos de cobertura, buffers alrededor de rutas, elementos individuales.

**Relevancia:** Si necesitamos generar mapas estáticos o visualizaciones de cobertura de redes desde nuestros datos GTFS.

---

## Perfiles de desarrolladores

### Gonzalo Fuentes — Perfil

**Quién es:** iOS Developer, fundador de Metrociego Madrid. Software Engineer en GMV (satélites Meteosat).

**GitHub:** https://github.com/GonzaloFuentes28

**Repos útiles:**
- `LiquidGlassCheatsheet` — iOS 26 Liquid Glass (168 stars)
- `AppMRR` — Revenue leaderboard con RevenueCat (MIT)
- `dimeApp` — Expense tracker iOS, referencia de diseño (fork, GPL)
- `ServerSetup` — Scripts Shell para configurar servidores
- `MovieBrowser` — Ejemplo de app con API externa

### xBaank

**Quién es:** Desarrollador de MadridTransporte (app competidora de transporte Madrid).

**GitHub:** https://github.com/xBaank

**Repos relevantes:**
- `MadridTransporte` — App transporte público Madrid (web/PWA + Android)
- `UnmaskedLeague` — App para League of Legends

### dieguezz (Diego Segura)

**GitHub:** https://github.com/dieguezz

**Repos relevantes:**
- `mcp-madrid-public-transport` — MCP server para transporte Madrid con Claude
- `terraform-gcp-vpn` — Infraestructura VPN en GCP
