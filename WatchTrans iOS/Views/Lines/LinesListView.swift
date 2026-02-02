//
//  LinesListView.swift
//  WatchTrans iOS
//
//  Created by Juan Macias Gomez on 21/1/26.
//

import SwiftUI
import PDFKit

struct LinesListView: View {
    let dataService: DataService
    let locationService: LocationService
    let favoritesManager: FavoritesManager?

    @State private var showingPlanFor: TransportType?

    // Current province name helper
    private var currentProvince: String? {
        dataService.currentLocation?.provinceName.lowercased()
    }

    // Check if current location is Barcelona/Catalunya (for Rodalies branding)
    var isRodalies: Bool {
        dataService.currentLocation?.isRodalies ?? false
    }

    // Metro section title based on province
    var metroSectionTitle: String {
        guard let province = currentProvince else { return "Metro" }
        switch province {
        case "sevilla": return "Metro Sevilla"
        case "vizcaya", "bilbao": return "Metro Bilbao"
        case "valencia": return "Metrovalencia"
        case "málaga", "malaga": return "Metro Málaga"
        case "granada": return "Metro Granada"
        case "santa cruz de tenerife", "tenerife": return "Tranvía Tenerife"
        case "barcelona", "rodalies de catalunya": return "Metro Barcelona"
        default: return "Metro"
        }
    }

    // Tram section title based on province
    var tramSectionTitle: String {
        guard let province = currentProvince else { return "Tranvía" }
        switch province {
        case "sevilla": return "MetroCentro"
        case "zaragoza": return "Tranvía Zaragoza"
        case "alicante": return "TRAM Alicante"
        case "murcia": return "Tranvía Murcia"
        case "barcelona", "rodalies de catalunya": return "Tram Barcelona"
        default: return "Tranvía"
        }
    }

    // MARK: - Numeric Line Sorting

    /// Extract numeric sort key from line name (C1 -> 1.0, C4a -> 4.1, L10 -> 10.0)
    private func lineSortKey(_ name: String) -> Double {
        let lowercased = name.lowercased()

        // Remove common prefixes to get the numeric part
        var numericPart = lowercased
        for prefix in ["ml", "c", "r", "l", "t", "s"] {
            if numericPart.hasPrefix(prefix) {
                numericPart = String(numericPart.dropFirst(prefix.count))
                break
            }
        }

        // Handle suffixes like "4a", "4b", "8n", "8s"
        var baseNumber: Double = 0
        var suffix: Double = 0

        for (index, char) in numericPart.enumerated() {
            if char.isLetter {
                // Get base number from characters before this letter
                let baseString = String(numericPart.prefix(index))
                baseNumber = Double(baseString) ?? 0

                // Add small value for suffix (a=0.1, b=0.2, n=0.14, s=0.19)
                if let asciiValue = char.asciiValue {
                    suffix = Double(asciiValue - 97) * 0.01 // 'a' = 0.01, 'b' = 0.02
                }
                return baseNumber + suffix
            }
        }

        // No letter suffix, just return the number
        return Double(numericPart) ?? 0
    }

    /// Sort lines numerically (C1, C2, C3, ..., C10, not C1, C10, C2)
    private func sortedNumerically(_ lines: [Line]) -> [Line] {
        lines.sorted { lineSortKey($0.name) < lineSortKey($1.name) }
    }

    // Get Cercanias/Rodalies lines for the current location
    var cercaniasLines: [Line] {
        guard let province = currentProvince else {
            return sortedNumerically(dataService.filteredLines.filter { $0.type == .cercanias })
        }
        return sortedNumerically(dataService.filteredLines
            .filter { $0.type == .cercanias && $0.nucleo.lowercased() == province })
    }

    // Get Metro lines for the current location
    var metroLines: [Line] {
        guard let province = currentProvince else {
            return sortedNumerically(dataService.filteredLines.filter { $0.type == .metro })
        }
        return sortedNumerically(dataService.filteredLines
            .filter { $0.type == .metro && $0.nucleo.lowercased() == province })
    }

    // Get Metro Ligero lines for the current location
    var metroLigeroLines: [Line] {
        guard let province = currentProvince else {
            return sortedNumerically(dataService.filteredLines.filter { $0.type == .metroLigero })
        }
        return sortedNumerically(dataService.filteredLines
            .filter { $0.type == .metroLigero && $0.nucleo.lowercased() == province })
    }

    // Get Tram lines for the current location
    var tramLines: [Line] {
        guard let province = currentProvince else {
            return sortedNumerically(dataService.filteredLines.filter { $0.type == .tram })
        }
        return sortedNumerically(dataService.filteredLines
            .filter { $0.type == .tram && $0.nucleo.lowercased() == province })
    }

    // Get FGC lines for Barcelona
    var fgcLines: [Line] {
        guard let province = currentProvince else {
            return sortedNumerically(dataService.filteredLines.filter { $0.type == .fgc })
        }
        return sortedNumerically(dataService.filteredLines
            .filter { $0.type == .fgc && $0.nucleo.lowercased() == province })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    // Cercanias/Rodalies section
                    if !cercaniasLines.isEmpty {
                    Section {
                        ForEach(cercaniasLines) { line in
                            NavigationLink(destination: LineDetailView(
                                line: line,
                                dataService: dataService,
                                locationService: locationService,
                                favoritesManager: favoritesManager
                            )) {
                                LineRowView(line: line)
                            }
                        }
                    } header: {
                        SectionHeaderWithPlan(
                            logo: LogoImageView(
                                logoType: isRodalies ? .rodalies : .cercanias,
                                height: 22
                            ),
                            title: isRodalies ? "Rodalies" : "Cercanías",
                            onShowPlan: { showingPlanFor = .cercanias }
                        )
                    }
                }

                // Metro section
                if !metroLines.isEmpty {
                    Section {
                        ForEach(metroLines) { line in
                            NavigationLink(destination: LineDetailView(
                                line: line,
                                dataService: dataService,
                                locationService: locationService,
                                favoritesManager: favoritesManager
                            )) {
                                LineRowView(line: line)
                            }
                        }
                    } header: {
                        SectionHeaderWithPlan(
                            logo: LogoImageView(
                                logoType: .metro(nucleo: dataService.currentLocation?.provinceName ?? "Madrid"),
                                height: 18
                            ),
                            title: metroSectionTitle,
                            onShowPlan: { showingPlanFor = .metro }
                        )
                    }
                }

                // Metro Ligero section
                if !metroLigeroLines.isEmpty {
                    Section {
                        ForEach(metroLigeroLines) { line in
                            NavigationLink(destination: LineDetailView(
                                line: line,
                                dataService: dataService,
                                locationService: locationService,
                                favoritesManager: favoritesManager
                            )) {
                                LineRowView(line: line)
                            }
                        }
                    } header: {
                        SectionHeaderWithPlan(
                            logo: LogoImageView(
                                logoType: .metroLigero,
                                height: 18
                            ),
                            title: "Metro Ligero",
                            onShowPlan: { showingPlanFor = .metroLigero }
                        )
                    }
                }

                // Tram section
                if !tramLines.isEmpty {
                    Section {
                        ForEach(tramLines) { line in
                            NavigationLink(destination: LineDetailView(
                                line: line,
                                dataService: dataService,
                                locationService: locationService,
                                favoritesManager: favoritesManager
                            )) {
                                LineRowView(line: line)
                            }
                        }
                    } header: {
                        SectionHeaderWithPlan(
                            logo: LogoImageView(
                                logoType: .tram(nucleo: dataService.currentLocation?.provinceName ?? ""),
                                height: 18
                            ),
                            title: tramSectionTitle,
                            onShowPlan: { showingPlanFor = .tram }
                        )
                    }
                }

                // FGC section (Barcelona only)
                if !fgcLines.isEmpty {
                    Section {
                        ForEach(fgcLines) { line in
                            NavigationLink(destination: LineDetailView(
                                line: line,
                                dataService: dataService,
                                locationService: locationService,
                                favoritesManager: favoritesManager
                            )) {
                                LineRowView(line: line)
                            }
                        }
                    } header: {
                        SectionHeaderWithPlan(
                            logo: LogoImageView(
                                logoType: .fgc,
                                height: 22
                            ),
                            title: "Ferrocarrils (FGC)",
                            onShowPlan: { showingPlanFor = .fgc }
                        )
                    }
                }

                // Empty state
                if cercaniasLines.isEmpty && metroLines.isEmpty && metroLigeroLines.isEmpty && tramLines.isEmpty && fgcLines.isEmpty {
                    if dataService.isLoading {
                        HStack {
                            Spacer()
                            ProgressView("Cargando lineas...")
                            Spacer()
                        }
                    } else {
                        Text("No hay lineas disponibles para tu ubicacion")
                            .foregroundStyle(.secondary)
                    }
                }
                }
                .listStyle(.insetGrouped)
                .navigationTitle(dataService.currentLocation?.provinceName ?? "Lineas")

                // Loading overlay
                if dataService.isLoadingLines {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Cargando líneas...")
                            .padding(.top, 8)
                    }
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .task {
                // Lazy load lines when user enters this view
                await loadLinesIfNeeded()
                // Cache line itineraries for offline use when in a province
                await cacheItinerariesIfNeeded()
            }
            .fullScreenCover(item: $showingPlanFor) { lineType in
                NetworkPlanView(
                    lineType: lineType,
                    nucleo: dataService.currentLocation?.provinceName ?? "madrid"
                )
            }
        }
    }

    /// Load lines on demand (lazy loading)
    private func loadLinesIfNeeded() async {
        guard let location = SharedStorage.shared.getLocation() else { return }
        await dataService.fetchLinesIfNeeded(latitude: location.latitude, longitude: location.longitude)
    }

    /// Cache all line itineraries for the current province (for offline use)
    private func cacheItinerariesIfNeeded() async {
        guard NetworkMonitor.shared.isConnected else { return }
        guard let province = dataService.currentLocation?.provinceName else { return }

        await OfflineLineService.shared.cacheItinerariesForProvince(
            province: province,
            lines: dataService.filteredLines,
            dataService: dataService
        )
    }
}

// MARK: - Line Row View

struct LineRowView: View {
    let line: Line

    var lineColor: Color {
        Color(hex: line.colorHex) ?? .blue
    }

    /// Metro Ligero uses inverted style: white background, colored border and text
    var isMetroLigero: Bool {
        line.type == .metroLigero
    }

    var body: some View {
        HStack(spacing: 12) {
            // Line badge
            if isMetroLigero {
                // Metro Ligero: white background, colored border and text
                Text(line.name)
                    .font(.headline)
                    .fontWeight(.heavy)
                    .foregroundStyle(lineColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(lineColor, lineWidth: 2)
                            )
                    )
                    .frame(minWidth: 50)
            } else {
                // Standard: colored background, white text
                Text(line.name)
                    .font(.headline)
                    .fontWeight(.heavy)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(lineColor)
                    )
                    .frame(minWidth: 50)
            }

            // Line description
            VStack(alignment: .leading, spacing: 2) {
                Text(line.longName)
                    .font(.subheadline)
                    .lineLimit(2)

                Text(line.type.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Section Header with Plan Button

struct SectionHeaderWithPlan<Logo: View>: View {
    let logo: Logo
    let title: String
    let onShowPlan: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            logo
            Text(title)
            Spacer()
            Button {
                onShowPlan()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "map")
                    Text("Ver Plano")
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Network Plan View (Full Screen)

struct NetworkPlanView: View {
    let lineType: TransportType
    let nucleo: String

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var pdfDocument: PDFDocument?
    @State private var isLoadingPDF = false
    @State private var pdfLoadError = false

    private let baseURL = "https://redcercanias.com/static/planos"

    /// Static plan URLs from the server
    /// Some are images (viewable in-app), others are PDFs (open in Safari)
    private var planInfo: (url: URL, isPDF: Bool)? {
        let nucleoLower = nucleo.lowercased()
        DebugLog.log("🗺️ [Plan] Getting plan for lineType=\(lineType), nucleo='\(nucleo)' -> '\(nucleoLower)'")

        let path: String?
        var isPDF = true

        switch lineType {
        case .metro:
            switch nucleoLower {
            case "málaga", "malaga":
                path = "metro/malaga_metro.pdf"
            case "bilbao", "vizcaya":
                path = "metro/bilbao_metro.pdf"
            case "madrid":
                path = "metro/madrid_metro.pdf"
            case "barcelona":
                path = "metro/barcelona_metro.pdf"
            case "sevilla":
                path = "metro/sevilla_metro.png"
                isPDF = false
            case "granada":
                path = "metro/granada_metro.pdf"
            case "valencia":
                path = "metro/valencia_metro.pdf"
            case "tenerife":
                path = "metro/tenerife_metro.png"
                isPDF = false
            default:
                path = nil
            }
        case .metroLigero:
            path = "metro_ligero/madrid_metro_ligero.pdf"
        case .cercanias:
            switch nucleoLower {
            case "madrid":
                path = "cercanias/madrid_cercanias.pdf"
            case "barcelona", "rodalies de catalunya":
                path = "cercanias/barcelona_cercanias.pdf"
            case "sevilla":
                path = "cercanias/sevilla_cercanias.pdf"
            case "valencia":
                path = "cercanias/valencia_cercanias.pdf"
            case "bilbao", "vizcaya":
                path = "cercanias/bilbao_cercanias.pdf"
            case "málaga", "malaga":
                path = "cercanias/malaga_cercanias.pdf"
            case "san sebastián", "san sebastian", "guipúzcoa", "guipuzcoa", "donostia":
                path = "cercanias/san_sebastian_cercanias.pdf"
            case "santander", "cantabria":
                path = "cercanias/santander_cercanias.pdf"
            case "asturias", "oviedo", "gijón", "gijon":
                path = "cercanias/asturias_cercanias.pdf"
            case "murcia", "alicante", "murcia/alicante":
                path = "cercanias/murcia_alicante_cercanias.pdf"
            case "zaragoza", "aragón", "aragon":
                path = "cercanias/zaragoza_cercanias.pdf"
            case "cádiz", "cadiz":
                path = "cercanias/cadiz_cercanias.pdf"
            default:
                path = nil
            }
        case .fgc:
            path = "fgc/barcelona_fgc.pdf"
        case .tram:
            switch nucleoLower {
            case "parla", "madrid":
                path = "tranvia/parla_tranvia.pdf"
            case "zaragoza":
                path = "tranvia/zaragoza_tranvia.pdf"
            case "barcelona":
                path = "tranvia/barcelona_tranvia.pdf"
            case "tenerife":
                path = "tranvia/tenerife_tranvia.pdf"
            case "sevilla":
                path = "tranvia/sevilla_tranvia.pdf"
            case "murcia":
                path = "tranvia/murcia_tranvia.pdf"
            case "alicante":
                path = "tranvia/alicante_tranvia.pdf"
            default:
                path = nil
            }
        }

        guard let path = path, let url = URL(string: "\(baseURL)/\(path)") else {
            return nil
        }
        return (url, isPDF)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()

                    if let info = planInfo {
                        if info.isPDF {
                            // PDF: Show with native PDFKit viewer
                            if isLoadingPDF {
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .tint(.white)
                                    Text("Cargando plano...")
                                        .foregroundStyle(.white)
                                }
                            } else if pdfLoadError {
                                VStack(spacing: 16) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.largeTitle)
                                        .foregroundStyle(.orange)
                                    Text("No se pudo cargar el plano")
                                        .foregroundStyle(.white)
                                    Button("Reintentar") {
                                        Task { await loadPDF(from: info.url) }
                                    }
                                    .foregroundStyle(.blue)
                                }
                            } else if let document = pdfDocument {
                                PDFKitView(document: document)
                            }
                        } else {
                            // Image: Show with zoom/pan
                            AsyncImage(url: info.url) { phase in
                                switch phase {
                                case .empty:
                                    VStack(spacing: 16) {
                                        ProgressView()
                                            .tint(.white)
                                        Text("Cargando plano...")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                    }
                                    .onAppear {
                                        DebugLog.log("🗺️ [Plan] Loading image: \(info.url.absoluteString)")
                                    }
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .scaleEffect(scale)
                                        .offset(offset)
                                        .gesture(
                                            MagnificationGesture()
                                                .onChanged { value in
                                                    scale = lastScale * value
                                                }
                                                .onEnded { _ in
                                                    lastScale = scale
                                                    // Limit zoom
                                                    if scale < 1.0 {
                                                        withAnimation {
                                                            scale = 1.0
                                                            lastScale = 1.0
                                                        }
                                                    } else if scale > 5.0 {
                                                        scale = 5.0
                                                        lastScale = 5.0
                                                    }
                                                }
                                        )
                                        .simultaneousGesture(
                                            DragGesture()
                                                .onChanged { value in
                                                    offset = CGSize(
                                                        width: lastOffset.width + value.translation.width,
                                                        height: lastOffset.height + value.translation.height
                                                    )
                                                }
                                                .onEnded { _ in
                                                    lastOffset = offset
                                                }
                                        )
                                        .onTapGesture(count: 2) {
                                            withAnimation {
                                                scale = 1.0
                                                lastScale = 1.0
                                                offset = .zero
                                                lastOffset = .zero
                                            }
                                        }
                                case .failure(let error):
                                    VStack(spacing: 16) {
                                        Image(systemName: "exclamationmark.triangle")
                                            .font(.largeTitle)
                                            .foregroundStyle(.orange)
                                        Text("No se pudo cargar el plano")
                                            .foregroundStyle(.white)
                                        Text(info.url.lastPathComponent)
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                    }
                                    .onAppear {
                                        DebugLog.log("🗺️ [Plan] ❌ Image load failed: \(error.localizedDescription)")
                                        DebugLog.log("🗺️ [Plan] URL was: \(info.url.absoluteString)")
                                    }
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                    } else {
                        // No plan available
                        VStack(spacing: 16) {
                            Image(systemName: "map")
                                .font(.largeTitle)
                                .foregroundStyle(.gray)
                            Text("Plano no disponible")
                                .foregroundStyle(.white)
                            Text("Aun no tenemos plano para esta red")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                    }
                }
            }
            .navigationTitle(planTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.8), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
            .task {
                if let info = planInfo, info.isPDF {
                    await loadPDF(from: info.url)
                }
            }
        }
    }

    private func loadPDF(from url: URL) async {
        isLoadingPDF = true
        pdfLoadError = false

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let document = PDFDocument(data: data) {
                await MainActor.run {
                    pdfDocument = document
                    isLoadingPDF = false
                }
            } else {
                await MainActor.run {
                    pdfLoadError = true
                    isLoadingPDF = false
                }
            }
        } catch {
            await MainActor.run {
                pdfLoadError = true
                isLoadingPDF = false
            }
        }
    }

    private var planTitle: String {
        switch lineType {
        case .cercanias: return "Plano Cercanías"
        case .metro: return "Plano Metro"
        case .metroLigero: return "Plano Metro Ligero"
        case .tram: return "Plano Tranvía"
        case .fgc: return "Plano FGC"
        }
    }
}

// MARK: - PDFKit View Wrapper

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .black
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}

#Preview {
    LinesListView(
        dataService: DataService(),
        locationService: LocationService(),
        favoritesManager: nil
    )
}
