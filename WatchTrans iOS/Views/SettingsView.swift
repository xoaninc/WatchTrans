//
//  SettingsView.swift
//  WatchTrans iOS
//
//  Created by Juan Macias Gomez on 21/1/26.
//

import SwiftUI
import PulseUI

struct SettingsView: View {
    let dataService: DataService
// ... (rest of imports and properties)


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

    /// Networks grouped by transport type with real names from loaded lines
    private var availableNetworks: [(type: TransportType, nucleo: String, lineCount: Int)] {
        var seen = Set<String>()
        var result: [(TransportType, String, Int)] = []
        for line in dataService.lines {
            let key = "\(line.type.rawValue)-\(line.nucleo.lowercased())"
            if !seen.contains(key) {
                seen.insert(key)
                let count = dataService.lines.filter { $0.type == line.type && $0.nucleo.lowercased() == line.nucleo.lowercased() }.count
                result.append((line.type, line.nucleo, count))
            }
        }
        return result.sorted { $0.0.rawValue < $1.0.rawValue }
    }

    // MARK: - Dynamic Credits

    struct CreditItem: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let color: Color
        let isCustomAsset: Bool
    }

    /// Credits derived from loaded networks
    private var relevantCredits: [CreditItem] {
        var credits: [CreditItem] = []
        let loadedTypes = Set(dataService.lines.map { $0.type })
        for network in dataService.networks {
            guard let tt = network.transportType else { continue }
            let type: TransportType
            switch tt {
            case "metro", "metro_ligero": type = .metro
            case "tram": type = .tram
            case "bus": type = .bus
            default: type = .tren
            }
            guard loadedTypes.contains(type) else { continue }
            let icon: String
            let color: Color
            switch type {
            case .metro: icon = "MetroSymbol"; color = .red
            case .tren: icon = "TrenSymbol"; color = .cyan
            case .tram: icon = "TramSymbol"; color = .green
            case .bus: icon = "BusSymbol"; color = .orange
            case .funicular: icon = "FunicularSymbol"; color = .brown
            }
            credits.append(CreditItem(name: network.name, icon: icon, color: color, isCustomAsset: true))
        }
        return credits
    }

    var body: some View {
        NavigationStack {
            List {
                // About section
                Section {
                    HStack {
                        SymbolView(name: "TrenSymbol", size: 34)
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

                // Sincronización section
                Section {
                    HStack {
                        Image(systemName: "icloud.fill")
                            .foregroundStyle(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Favoritos en iCloud")
                                .font(.body)
                            
                            if let lastSync = iCloudSyncService.shared.lastSyncTimestamp {
                                Text("Última vez: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("No sincronizado")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            iCloudSyncService.shared.syncOnLaunch()
                            // Force Haptic
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                        } label: {
                            Image(systemName: "arrow.clockwise.icloud")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    if !iCloudSyncService.shared.isAvailable {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            Text("Inicia sesión en iCloud para sincronizar")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Sincronización")
                } footer: {
                    Text("Tus favoritos se sincronizan automáticamente entre tu iPhone, Apple Watch y otros dispositivos.")
                }

                // Transport type filter
                if !availableNetworks.isEmpty {
                    Section {
                        ForEach(availableNetworks, id: \.type) { network in
                            Toggle(isOn: Binding(
                                get: { enabledTypes.contains(network.type) },
                                set: { isEnabled in
                                    if isEnabled {
                                        enabledTypes.insert(network.type)
                                    } else {
                                        enabledTypes.remove(network.type)
                                    }
                                    saveEnabledTypes()
                                }
                            )) {
                                HStack(spacing: 10) {
                                    LogoImageView(
                                        type: network.type,
                                        height: 22
                                    )
                                    .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(networkDisplayName(type: network.type, nucleo: network.nucleo))
                                            .font(.body)
                                        Text("\(network.lineCount) línea\(network.lineCount == 1 ? "" : "s")")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Redes de transporte")
                    } footer: {
                        Text("Filtra las redes que se muestran. Sin selección = todas.")
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

                // Credits section (dynamic based on province + full attribution)
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        if !relevantCredits.isEmpty {
                            Text("En tu zona:")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)

                            ForEach(relevantCredits) { credit in
                                HStack {
                                    if credit.isCustomAsset {
                                        SymbolView(name: credit.icon, size: 16)
                                            .foregroundStyle(credit.color)
                                    } else {
                                        Image(systemName: credit.icon)
                                            .foregroundStyle(credit.color)
                                    }
                                    Text(credit.name)
                                }
                            }
                            
                            Divider()
                        }
                        
                        NavigationLink {
                            DataSourcesView()
                        } label: {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(.blue)
                                Text("Fuentes de datos y Licencias")
                                Spacer()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Creditos")
                } footer: {
                    Text("WatchTrans utiliza datos abiertos bajo las licencias de cada operador.")
                }

                // Developer section (hidden until activated)
                if developerModeEnabled {
                    Section {
                        NavigationLink {
                            ConsoleView()
                        } label: {
                            HStack {
                                Image(systemName: "network")
                                Text("Consola de Red (Pulse)")
                            }
                        }

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

    /// Display name for a network based on type + nucleo (no hardcoding)
    private func networkDisplayName(type: TransportType, nucleo: String) -> String {
        let capitalized = nucleo.prefix(1).uppercased() + nucleo.dropFirst()
        switch type {
        case .metro: return "Metro de \(capitalized)"
        case .tren: return "Tren de \(capitalized)"
        case .tram: return "Tranvía de \(capitalized)"
        case .bus: return "Bus \(capitalized)"
        case .funicular: return "Funicular de \(capitalized)"
        }
    }

    private func colorForTransportType(_ type: TransportType) -> Color {
        switch type {
        case .metro:
            return .orange
        case .tren:
            return .blue
        case .tram:
            return .green
        case .bus:
            return .red
        case .funicular:
            return .brown
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

            // 2. Clear ALL DataService caches (arrivals, stops, lines, colors, platforms, shapes)
            dataService.clearAllPersistentCaches()

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
