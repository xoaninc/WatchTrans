//
//  SettingsView.swift
//  WatchTrans iOS
//
//  Created by Juan Macias Gomez on 21/1/26.
//

import SwiftUI

struct SettingsView: View {
    let dataService: DataService

    @AppStorage("showDelayNotifications") private var showDelayNotifications = true
    @AppStorage("autoRefreshEnabled") private var autoRefreshEnabled = true
    @AppStorage("enabledTransportTypes") private var enabledTransportTypesData: Data = Data()

    // Transport type filter
    @State private var enabledTypes: Set<TransportType> = []

    // Cache clearing state
    @State private var isClearingCache = false
    @State private var showCacheCleared = false

    // Developer mode state
    @State private var versionTapCount = 0
    @State private var developerModeEnabled = false
    @State private var showTokenInput = false
    @State private var tokenInput = ""
    @State private var isReloading = false
    @State private var reloadMessage: String?
    @State private var showReloadAlert = false

    // Developer password protection
    @State private var showDevPasswordPrompt = false
    @State private var devPasswordInput = ""
    @State private var showWrongPasswordAlert = false

    /// Available transport types based on current location's lines
    private var availableTransportTypes: [TransportType] {
        let types = Set(dataService.lines.map { $0.type })
        return Array(types).sorted { $0.rawValue < $1.rawValue }
    }

    // MARK: - Dynamic Credits

    struct CreditItem: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let color: Color
    }

    /// Credits relevant to the current province
    private var relevantCredits: [CreditItem] {
        let province = dataService.currentLocation?.provinceName.lowercased() ?? ""

        var credits: [CreditItem] = []

        switch province {
        case "madrid":
            credits.append(CreditItem(name: "RENFE Cercanías", icon: "tram.fill", color: .cyan))
            credits.append(CreditItem(name: "Metro de Madrid", icon: "tram.tunnel.fill", color: .red))
            if dataService.lines.contains(where: { $0.type == .metroLigero }) {
                credits.append(CreditItem(name: "Metro Ligero", icon: "tram.fill", color: .blue))
            }

        case "barcelona", "rodalies de catalunya":
            credits.append(CreditItem(name: "Rodalies de Catalunya", icon: "tram.fill", color: .purple))
            credits.append(CreditItem(name: "TMB Metro Barcelona", icon: "tram.tunnel.fill", color: .red))
            credits.append(CreditItem(name: "FGC", icon: "tram.fill", color: .orange))
            if dataService.lines.contains(where: { $0.type == .tram }) {
                credits.append(CreditItem(name: "Tram Barcelona", icon: "tram", color: .green))
            }

        case "sevilla":
            credits.append(CreditItem(name: "Cercanías Sevilla", icon: "tram.fill", color: .cyan))
            credits.append(CreditItem(name: "Metro Sevilla", icon: "tram.tunnel.fill", color: .red))

        case "valencia":
            credits.append(CreditItem(name: "Cercanías Valencia", icon: "tram.fill", color: .cyan))
            credits.append(CreditItem(name: "Metrovalencia", icon: "tram.tunnel.fill", color: .red))

        case "vizcaya", "bilbao":
            credits.append(CreditItem(name: "Cercanías Bilbao", icon: "tram.fill", color: .cyan))
            credits.append(CreditItem(name: "Metro Bilbao", icon: "tram.tunnel.fill", color: .red))

        case "málaga", "malaga":
            credits.append(CreditItem(name: "Cercanías Málaga", icon: "tram.fill", color: .cyan))
            credits.append(CreditItem(name: "Metro Málaga", icon: "tram.tunnel.fill", color: .red))

        case "asturias":
            credits.append(CreditItem(name: "Cercanías Asturias", icon: "tram.fill", color: .cyan))

        case "cantabria", "santander":
            credits.append(CreditItem(name: "Cercanías Santander", icon: "tram.fill", color: .cyan))

        case "murcia":
            credits.append(CreditItem(name: "Cercanías Murcia", icon: "tram.fill", color: .cyan))
            if dataService.lines.contains(where: { $0.type == .tram }) {
                credits.append(CreditItem(name: "Tranvía Murcia", icon: "tram", color: .green))
            }

        case "cádiz", "cadiz":
            credits.append(CreditItem(name: "Cercanías Cádiz", icon: "tram.fill", color: .cyan))

        case "zaragoza":
            credits.append(CreditItem(name: "Tranvía Zaragoza", icon: "tram", color: .green))

        case "alicante":
            credits.append(CreditItem(name: "TRAM Alicante", icon: "tram", color: .green))

        default:
            // Fallback: show based on available transport types
            if dataService.lines.contains(where: { $0.type == .cercanias }) {
                credits.append(CreditItem(name: "RENFE Cercanías", icon: "tram.fill", color: .cyan))
            }
            if dataService.lines.contains(where: { $0.type == .metro }) {
                credits.append(CreditItem(name: "Metro", icon: "tram.tunnel.fill", color: .red))
            }
            if dataService.lines.contains(where: { $0.type == .metroLigero }) {
                credits.append(CreditItem(name: "Metro Ligero", icon: "tram.fill", color: .blue))
            }
            if dataService.lines.contains(where: { $0.type == .tram }) {
                credits.append(CreditItem(name: "Tranvía", icon: "tram", color: .green))
            }
            if dataService.lines.contains(where: { $0.type == .fgc }) {
                credits.append(CreditItem(name: "FGC", icon: "tram.fill", color: .orange))
            }
        }

        return credits
    }

    var body: some View {
        NavigationStack {
            List {
                // About section
                Section {
                    HStack {
                        Image(systemName: "tram.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading) {
                            Text("WatchTrans")
                                .font(.headline)
                            Text("Version 1.0.0")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        handleVersionTap()
                    }
                } header: {
                    Text("Acerca de")
                }

                // Preferences section
                Section {
                    Toggle("Auto-refrescar datos", isOn: $autoRefreshEnabled)
                } header: {
                    Text("Preferencias")
                }

                // Transport type filter
                if !availableTransportTypes.isEmpty {
                    Section {
                        ForEach(availableTransportTypes, id: \.self) { type in
                            Toggle(isOn: Binding(
                                get: { enabledTypes.contains(type) },
                                set: { isEnabled in
                                    if isEnabled {
                                        enabledTypes.insert(type)
                                    } else {
                                        enabledTypes.remove(type)
                                    }
                                    saveEnabledTypes()
                                }
                            )) {
                                HStack {
                                    Image(systemName: iconForTransportType(type))
                                        .foregroundStyle(colorForTransportType(type))
                                    Text(type.rawValue)
                                }
                            }
                        }
                    } header: {
                        Text("Tipos de Transporte")
                    } footer: {
                        Text("Filtra las lineas que se muestran. Sin seleccion = todas.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                // Data section
                Section {
                    Button {
                        clearCache()
                    } label: {
                        HStack {
                            Text(showCacheCleared ? "Cache limpiada" : "Limpiar cache")
                            Spacer()
                            if isClearingCache {
                                ProgressView()
                            } else if showCacheCleared {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .foregroundStyle(showCacheCleared ? .green : .red)
                    .disabled(isClearingCache)
                } header: {
                    Text("Datos")
                } footer: {
                    Text("Borra llegadas, horarios offline e itinerarios. Los favoritos no se eliminan.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // Links section
                Section {
                    if let websiteURL = URL(string: "https://xoaninc.github.io/WatchTrans-App-website-/") {
                        Link(destination: websiteURL) {
                            HStack {
                                Image(systemName: "globe")
                                Text("Sitio web")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let supportURL = URL(string: "https://xoaninc.github.io/WatchTrans-App-website-/support.html") {
                        Link(destination: supportURL) {
                            HStack {
                                Image(systemName: "questionmark.circle")
                                Text("Soporte y FAQ")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let privacyURL = URL(string: "https://xoaninc.github.io/WatchTrans-App-website-/privacy.html") {
                        Link(destination: privacyURL) {
                            HStack {
                                Image(systemName: "hand.raised")
                                Text("Politica de privacidad")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let issuesURL = URL(string: "https://github.com/xoaninc/WatchTrans/issues") {
                        Link(destination: issuesURL) {
                            HStack {
                                Image(systemName: "exclamationmark.bubble")
                                Text("Reportar problema")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Soporte")
                }

                // Credits section (dynamic based on province)
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Datos proporcionados por:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(relevantCredits) { credit in
                            HStack {
                                Image(systemName: credit.icon)
                                    .foregroundStyle(credit.color)
                                Text(credit.name)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Creditos")
                }

                // Developer section (hidden until activated)
                if developerModeEnabled {
                    Section {
                        if AdminService.hasToken() {
                            // Token configured - show reload button
                            Button {
                                Task { await reloadGTFS() }
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Recargar GTFS")
                                    Spacer()
                                    if isReloading {
                                        ProgressView()
                                    }
                                }
                            }
                            .disabled(isReloading)

                            Button("Eliminar token", role: .destructive) {
                                AdminService.removeToken()
                            }
                        } else {
                            // No token - show input
                            SecureField("Admin Token", text: $tokenInput)
                                .textContentType(.password)
                                .autocorrectionDisabled()

                            Button("Guardar token") {
                                if AdminService.saveToken(tokenInput) {
                                    tokenInput = ""
                                }
                            }
                            .disabled(tokenInput.isEmpty)
                        }
                    } header: {
                        HStack {
                            Image(systemName: "hammer.fill")
                            Text("Desarrollador")
                        }
                    } footer: {
                        Text("Funciones de administracion del servidor.")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Ajustes")
            .alert("GTFS Reload", isPresented: $showReloadAlert) {
                Button("OK") { }
            } message: {
                Text(reloadMessage ?? "")
            }
            .alert("Modo Desarrollador", isPresented: $showDevPasswordPrompt) {
                SecureField("Contraseña", text: $devPasswordInput)
                Button("Cancelar", role: .cancel) {
                    devPasswordInput = ""
                }
                Button("Acceder") {
                    verifyDeveloperPassword()
                }
            } message: {
                Text("Introduce la contraseña de desarrollador")
            }
            .alert("Error", isPresented: $showWrongPasswordAlert) {
                Button("OK") { }
            } message: {
                Text("Contraseña incorrecta")
            }
            .onAppear {
                loadEnabledTypes()
            }
        }
    }

    // MARK: - Transport Type Helpers

    private func iconForTransportType(_ type: TransportType) -> String {
        switch type {
        case .metro:
            return "tram.tunnel.fill"
        case .metroLigero:
            return "tram.fill"
        case .cercanias:
            return "tram.fill"
        case .tram:
            return "tram"
        case .fgc:
            return "tram.fill"
        }
    }

    private func colorForTransportType(_ type: TransportType) -> Color {
        switch type {
        case .metro:
            return .red
        case .metroLigero:
            return .blue
        case .cercanias:
            return .purple
        case .tram:
            return .green
        case .fgc:
            return .orange
        }
    }

    private func saveEnabledTypes() {
        if let data = try? JSONEncoder().encode(Array(enabledTypes)) {
            enabledTransportTypesData = data
        }
    }

    private func loadEnabledTypes() {
        if let types = try? JSONDecoder().decode([TransportType].self, from: enabledTransportTypesData) {
            enabledTypes = Set(types)
        } else {
            // Default: all types enabled (empty set means show all)
            enabledTypes = []
        }
    }

    // MARK: - Developer Mode

    private func handleVersionTap() {
        versionTapCount += 1

        if versionTapCount >= 7 && !developerModeEnabled {
            // Show password prompt instead of directly enabling
            showDevPasswordPrompt = true
            versionTapCount = 0
        }

        // Reset counter after 3 seconds of inactivity
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if versionTapCount < 7 {
                versionTapCount = 0
            }
        }
    }

    private func verifyDeveloperPassword() {
        if devPasswordInput == Secrets.developerPassword {
            developerModeEnabled = true
            devPasswordInput = ""
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } else {
            showWrongPasswordAlert = true
            devPasswordInput = ""
            // Error haptic
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }

    private func reloadGTFS() async {
        isReloading = true
        defer { isReloading = false }

        let result = await AdminService.reloadGTFS()

        switch result {
        case .success(let message):
            reloadMessage = "✅ \(message)"
        case .unauthorized:
            reloadMessage = "❌ Token inválido"
        case .error(let error):
            reloadMessage = "❌ Error: \(error)"
        case .noToken:
            reloadMessage = "❌ No hay token configurado"
        }

        showReloadAlert = true
    }

    private func clearCache() {
        isClearingCache = true
        showCacheCleared = false

        Task {
            // 1. Clear HTTP cache
            URLCache.shared.removeAllCachedResponses()

            // 2. Clear arrival cache in DataService
            dataService.clearArrivalCache()

            // 3. Clear offline schedules
            await OfflineScheduleService.shared.clearCache()

            // 4. Clear offline line itineraries
            await OfflineLineService.shared.clearAllCache()

            // 5. Clear UserDefaults cache keys (but not favorites or settings)
            let keysToRemove = ["lastLocationTimestamp", "lastLatitude", "lastLongitude"]
            for key in keysToRemove {
                UserDefaults.standard.removeObject(forKey: key)
            }

            // Update UI and haptic feedback
            await MainActor.run {
                isClearingCache = false
                showCacheCleared = true
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }

            // Reset "Cache limpiada" text after 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                showCacheCleared = false
            }
        }
    }
}

#Preview {
    SettingsView(dataService: DataService())
}
