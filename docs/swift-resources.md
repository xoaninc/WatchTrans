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

## Gonzalo Fuentes — Perfil

**Quién es:** iOS Developer, fundador de Metrociego Madrid. Software Engineer en GMV (satélites Meteosat).

**GitHub:** https://github.com/GonzaloFuentes28

**Repos útiles:**
- `LiquidGlassCheatsheet` — iOS 26 Liquid Glass
- `MovieBrowser` — Ejemplo de app con API externa
- `AppMRR` — Leaderboard de revenue apps iOS (RevenueCat)
