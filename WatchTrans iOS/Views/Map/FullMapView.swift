import SwiftUI
import MapKit

// Estructura auxiliar para asegurar que el Mapa reciba datos limpios y estables
struct MapShape: Identifiable {
    let id: String
    let coordinates: [CLLocationCoordinate2D]
    let color: Color
}

struct FullMapView: View {
    var dataService: DataService
    var locationService: LocationService
    
    private let gtfsService = GTFSRealtimeService()
    
    @AppStorage("visibleRouteIds") private var visibleRouteIdsString: String = ""
    
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var trainPositions: [EstimatedPositionResponse] = []
    
    // Lista única y estable para el renderizado
    @State private var visibleShapes: [MapShape] = []
    
    @State private var stops: [Stop] = [] 
    @State private var availableLines: [Line] = []
    @State private var timer: Timer?
    @State private var hasCenteredOnUser = false
    @State private var debugInfo: String = "Iniciando..."
    @State private var zoomLevel: Double = 0.1 // Default initial zoom (span delta)
    
    private var visibleIds: Set<String> {
        let trimmed = visibleRouteIdsString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "NONE" { return [] }
        return Set(trimmed.split(separator: ",").map(String.init))
    }
    
    // LOD Logic
    private func shouldShowStop(_ stop: Stop) -> Bool {
        if zoomLevel < 0.05 { return true } // High zoom: Show all
        return stop.isHub // Low zoom: Only Hubs
    }
    
    private func shouldShowStopName() -> Bool {
        return zoomLevel < 0.02 // Only show names at very high zoom
    }

    var body: some View {
        ZStack {
            Map(position: $position) {
                // 0. UBICACIÓN USUARIO
                UserAnnotation()
                
                // 1. LÍNEAS DE TRANSPORTE
                ForEach(visibleShapes) { shape in
                    MapPolyline(coordinates: shape.coordinates)
                        .stroke(shape.color, lineWidth: 4)
                }
                
                // 2. PARADAS
                ForEach(stops.prefix(200)) { stop in // Increased limit for better coverage
                    if isValidCoordinate(lat: stop.latitude, lon: stop.longitude) && shouldShowStop(stop) {
                        Annotation(stop.name, coordinate: CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)) {
                            VStack(spacing: 2) {
                                if shouldShowStopName() {
                                    Text(stop.name)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.primary)
                                        .padding(2)
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(4)
                                }
                                
                                Circle()
                                    .fill(.white)
                                    .frame(width: stop.isHub ? 8 : 5, height: stop.isHub ? 8 : 5)
                                    .overlay(Circle().stroke(.gray, lineWidth: stop.isHub ? 1.5 : 0.5))
                            }
                        }
                    }
                }
                
                // 3. TRENES
                ForEach(trainPositions, id: \.tripId) { train in
                    if isValidCoordinate(lat: train.position.latitude, lon: train.position.longitude) {
                        Annotation(train.tripId, coordinate: CLLocationCoordinate2D(latitude: train.position.latitude, longitude: train.position.longitude)) {
                            TrainAnnotationView(train: train)
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .onMapCameraChange { context in
                // Update zoom level for LOD
                zoomLevel = context.region.span.latitudeDelta
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            
            // Consola de estado (Debug)
            VStack {
                if !debugInfo.isEmpty {
                    Text(debugInfo)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(6)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .padding(.top, 60)
                }
                Spacer()
            }
            
            layersButton
        }
        .task {
            setupInitialZoom()
            await initialLoad()
        }
        .onChange(of: dataService.lines) { _, newLines in
            Task { await processAndLoadShapes(newLines) }
        }
        .onAppear { startRefreshTimer() }
        .onDisappear { stopRefreshTimer() }
    }
    
    /// Lines grouped by transport type for the layer selector
    private var linesByTransportType: [(type: TransportType, nucleo: String, lines: [Line])] {
        var groups: [String: (type: TransportType, nucleo: String, lines: [Line])] = [:]
        for line in availableLines {
            let key = "\(line.type.rawValue)-\(line.nucleo.lowercased())"
            if groups[key] != nil {
                groups[key]!.lines.append(line)
            } else {
                groups[key] = (line.type, line.nucleo, [line])
            }
        }
        return groups.values.sorted { $0.type.rawValue < $1.type.rawValue }
    }

    @State private var showLineSheet = false

    private var layersButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    showLineSheet = true
                } label: {
                    Image(systemName: "square.2.layers.3d")
                        .font(.title2)
                        .padding(10)
                        .background(.regularMaterial)
                        .clipShape(Circle())
                        .shadow(radius: 2)
                }
                .padding()
            }
            Spacer()
        }
        .sheet(isPresented: $showLineSheet) {
            LineFilterSheet(
                linesByTransportType: linesByTransportType,
                isVisible: { isVisible($0) },
                toggleLine: { toggleLine($0) },
                toggleAll: { toggleAllLines() },
                isAllSelected: isAllSelected,
                nucleo: dataService.currentLocation?.provinceName ?? ""
            )
            .presentationDetents([.medium, .large])
            .presentationContentInteraction(.scrolls)
            .presentationDragIndicator(.visible)
        }
    }

    private func networkDisplayName(type: TransportType, nucleo: String) -> String {
        let capitalized = nucleo.prefix(1).uppercased() + nucleo.dropFirst()
        switch type {
        case .metro: return "Metro de \(capitalized)"
        case .metroLigero: return "Metro Ligero de \(capitalized)"
        case .cercanias: return "Cercanías \(capitalized)"
        case .tram: return "Tranvía de \(capitalized)"
        case .fgc: return "FGC"
        case .euskotren: return "Euskotren"
        case .bus: return "Bus \(capitalized)"
        }
    }

    private func transportIcon(_ type: TransportType) -> String {
        switch type {
        case .metro: return "tram.tunnel.fill"
        case .metroLigero: return "tram.fill"
        case .cercanias: return "tram.fill"
        case .tram: return "lightrail.fill"
        case .fgc: return "tram.fill"
        case .euskotren: return "tram.fill"
        case .bus: return "bus.fill"
        }
    }

    // MARK: - Core Loading
    
    func initialLoad() async {
        // 1. Esperar a tener ubicación si es necesario
        if locationService.currentLocation == nil {
            await MainActor.run { debugInfo = "Buscando GPS..." }
            // Pequeña espera para que el GPS se estabilice
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        
        // 2. Forzar carga de líneas si está vacío
        if dataService.lines.isEmpty, let loc = locationService.currentLocation {
            await MainActor.run { debugInfo = "Cargando red de transporte..." }
            await dataService.fetchLinesIfNeeded(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
        }
        
        // 3. Cargar paradas y shapes
        let lines = dataService.lines
        let loadedStops = dataService.stops
        await MainActor.run { 
            self.availableLines = lines
            self.stops = loadedStops 
        }
        
        await processAndLoadShapes(lines)
        await loadTrainPositions()
    }
    
    func processAndLoadShapes(_ lines: [Line]) async {
        guard !lines.isEmpty else { return }

        // Capture visibility state NOW to avoid race conditions with @AppStorage
        let currentVisibleString = visibleRouteIdsString
        let currentVisibleIds: Set<String>
        if currentVisibleString.isEmpty {
            currentVisibleIds = Set(lines.map { $0.id }) // all visible
        } else if currentVisibleString == "NONE" {
            currentVisibleIds = []
        } else {
            currentVisibleIds = Set(currentVisibleString.split(separator: ",").map(String.init))
        }

        if currentVisibleIds.isEmpty {
            await MainActor.run {
                self.visibleShapes = []
                self.debugInfo = ""
            }
            return
        }

        await MainActor.run { debugInfo = "Descargando mapas de líneas..." }

        var newShapes: [MapShape] = []

        // Descarga secuencial o por bloques para no saturar
        for line in lines {
            // Solo procesamos si la línea es visible
            guard currentVisibleIds.contains(line.id) else { continue }
            
            for rId in line.routeIds {
                let points = await dataService.fetchRouteShape(routeId: rId)
                if points.count > 1 {
                    let coords = points.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
                    // Creación del color segura
                    let color = Color(hex: line.colorHex) ?? .blue
                    newShapes.append(MapShape(id: rId, coordinates: coords, color: color))
                }
            }
            
            // Actualización progresiva para que el usuario vea cómo aparecen
            let currentShapes = newShapes
            await MainActor.run { 
                self.visibleShapes = currentShapes
                self.debugInfo = "Líneas: \(currentShapes.count) visibles"
            }
        }
        
        await MainActor.run { 
            self.debugInfo = "" // Ocultar al terminar si todo ok
            if newShapes.isEmpty { self.debugInfo = "⚠️ No hay trazados disponibles" }
        }
    }

    // MARK: - Helpers
    
    private var isAllSelected: Bool {
        !availableLines.isEmpty && availableLines.allSatisfy { isVisible($0.id) }
    }
    
    private func isVisible(_ lineId: String) -> Bool {
        if visibleRouteIdsString.isEmpty { return true }
        if visibleRouteIdsString == "NONE" { return false }
        return visibleIds.contains(lineId)
    }
    
    private func toggleLine(_ id: String) {
        DebugLog.log("🗺️ [Map] toggleLine(\(id)) — before: \(visibleRouteIdsString.prefix(50))...")
        // If empty (all visible), initialize with all line IDs first
        var current: Set<String>
        if visibleRouteIdsString.isEmpty {
            current = Set(availableLines.map { $0.id })
            DebugLog.log("🗺️ [Map] Initialized with \(current.count) lines (was empty)")
        } else {
            current = visibleIds
        }
        let wasVisible = current.contains(id)
        if wasVisible { current.remove(id) } else { current.insert(id) }
        visibleRouteIdsString = current.isEmpty ? "NONE" : Array(current).joined(separator: ",")
        DebugLog.log("🗺️ [Map] toggleLine result: \(id) \(wasVisible ? "REMOVED" : "ADDED"), visible: \(current.count) lines")
        Task { await processAndLoadShapes(dataService.lines) }
    }
    
    private func toggleAllLines() {
        DebugLog.log("🗺️ [Map] toggleAllLines — isAllSelected: \(isAllSelected)")
        if isAllSelected {
            visibleRouteIdsString = "NONE"
            DebugLog.log("🗺️ [Map] Set to NONE (all hidden)")
        } else {
            visibleRouteIdsString = availableLines.map { $0.id }.joined(separator: ",")
            DebugLog.log("🗺️ [Map] Set to ALL (\(availableLines.count) lines)")
        }
        Task { await processAndLoadShapes(dataService.lines) }
    }
    
    private func isValidCoordinate(lat: Double, lon: Double) -> Bool {
        lat != 0 && lon != 0 && lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180
    }
    
    func loadTrainPositions() async {
        var allTrains: [EstimatedPositionResponse] = []
        if let location = dataService.currentLocation {
            for network in location.networks {
                // LLAMADA DIRECTA AL GTFS-RT con manejo de errores individual
                do {
                    let nt = try await gtfsService.fetchEstimatedPositionsForNetwork(networkId: network.code)
                    allTrains.append(contentsOf: nt)
                } catch {
                    print("🗺️ [Map] Error cargando trenes para \(network.code): \(error)")
                }
            }
        }
        await MainActor.run {
            withAnimation(.linear(duration: 15)) { self.trainPositions = allTrains }
        }
    }
    
    private func setupInitialZoom() {
        guard !hasCenteredOnUser, let userLocation = locationService.currentLocation else { return }
        let region = MKCoordinateRegion(center: userLocation.coordinate, latitudinalMeters: 10000, longitudinalMeters: 10000)
        Task { @MainActor in
            withAnimation { position = .region(region) }
            hasCenteredOnUser = true
        }
    }
    
    func startRefreshTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { _ in
            Task { await loadTrainPositions() }
        }
    }
    
    func stopRefreshTimer() { timer?.invalidate(); timer = nil }
}

// MARK: - Line Filter Bottom Sheet

struct LineFilterSheet: View {
    let linesByTransportType: [(type: TransportType, nucleo: String, lines: [Line])]
    let isVisible: (String) -> Bool
    let toggleLine: (String) -> Void
    let toggleAll: () -> Void
    let isAllSelected: Bool
    let nucleo: String

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Líneas")
                .font(.headline)
                .padding(.top, 16)
                .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Toggle all
                    HStack {
                        Image(systemName: isAllSelected ? "eye.slash" : "eye")
                        Text(isAllSelected ? "Ocultar todas" : "Mostrar todas")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.regularMaterial)
                    .cornerRadius(20)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        DebugLog.log("🗺️ [LineSheet] Toggle all tapped")
                        toggleAll()
                    }
                    .padding(.horizontal)

                    // Groups by transport type
                    ForEach(Array(linesByTransportType.enumerated()), id: \.offset) { _, group in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                LogoImageView(
                                    type: group.type,
                                    nucleo: group.nucleo,
                                    height: 22
                                )
                                Text(networkName(type: group.type, nucleo: group.nucleo))
                                    .font(.headline)
                            }
                            .padding(.horizontal)

                            FlowLayout(spacing: 8) {
                                ForEach(group.lines) { line in
                                    LineChip(
                                        line: line,
                                        isSelected: isVisible(line.id),
                                        onTap: { toggleLine(line.id) }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            DebugLog.log("🗺️ [LineSheet] Empty area tapped")
        }
    }

    private func networkName(type: TransportType, nucleo: String) -> String {
        let capitalized = nucleo.prefix(1).uppercased() + nucleo.dropFirst()
        switch type {
        case .metro: return "Metro de \(capitalized)"
        case .metroLigero: return "Metro Ligero de \(capitalized)"
        case .cercanias: return "Cercanías \(capitalized)"
        case .tram: return "Tranvía de \(capitalized)"
        case .fgc: return "FGC"
        case .euskotren: return "Euskotren"
        case .bus: return "Bus \(capitalized)"
        }
    }
}

// MARK: - Line Chip

struct LineChip: View {
    let line: Line
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 3) {
            Text(line.name)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? line.color : line.color.opacity(0.2))
                )

            Text(line.longName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: 100)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            DebugLog.log("🗺️ [LineSheet] Chip tapped: \(line.name) (id: \(line.id), selected: \(isSelected))")
            onTap()
        }
    }
}

// FlowLayout is defined in StopDetailView.swift