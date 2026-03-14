import SwiftUI

struct UnifiedSearchView: View {
    let dataService: DataService
    let locationService: LocationService
    let favoritesManager: FavoritesManager?
    
    @State private var searchMode = 1 // 0: Ruta, 1: Estaciones (Por defecto: Estaciones)

    var body: some View {
        VStack(spacing: 0) {
            // Selector de modo
            Picker("Modo de búsqueda", selection: $searchMode) {
                Text("Estaciones").tag(1)
                Text("Planificar Ruta").tag(0)
            }
            .pickerStyle(.segmented)
            .padding()
            .background(Color(.systemBackground))

            Divider()

            // Contenido dinámico
            if searchMode == 0 {
                JourneyPlannerView(
                    dataService: dataService,
                    locationService: locationService
                )
            } else {
                SearchView(
                    dataService: dataService,
                    locationService: locationService,
                    favoritesManager: favoritesManager
                )
            }
        }
    }
}