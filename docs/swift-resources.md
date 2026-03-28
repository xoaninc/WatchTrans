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

## Gonzalo Fuentes — Perfil

**Quién es:** iOS Developer, fundador de Metrociego Madrid. Software Engineer en GMV (satélites Meteosat).

**GitHub:** https://github.com/GonzaloFuentes28

**Repos útiles:**
- `LiquidGlassCheatsheet` — iOS 26 Liquid Glass (168 stars)
- `AppMRR` — Revenue leaderboard con RevenueCat (MIT)
- `dimeApp` — Expense tracker iOS, referencia de diseño (fork, GPL)
- `ServerSetup` — Scripts Shell para configurar servidores
- `MovieBrowser` — Ejemplo de app con API externa
