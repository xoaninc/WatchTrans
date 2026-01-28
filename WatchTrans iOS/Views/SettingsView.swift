//
//  SettingsView.swift
//  WatchTrans iOS
//
//  Created by Juan Macias Gomez on 21/1/26.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("showDelayNotifications") private var showDelayNotifications = true
    @AppStorage("autoRefreshEnabled") private var autoRefreshEnabled = true
    @AppStorage("preferredTransport") private var preferredTransport = "all"

    // Developer mode state
    @State private var versionTapCount = 0
    @State private var developerModeEnabled = false
    @State private var showTokenInput = false
    @State private var tokenInput = ""
    @State private var isReloading = false
    @State private var reloadMessage: String?
    @State private var showReloadAlert = false

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

                    Picker("Transporte preferido", selection: $preferredTransport) {
                        Text("Todos").tag("all")
                        Text("Cercanias").tag("cercanias")
                        Text("Metro").tag("metro")
                        Text("Tranvia").tag("tram")
                    }
                } header: {
                    Text("Preferencias")
                }

                // Data section
                Section {
                    Button("Limpiar cache") {
                        clearCache()
                    }
                    .foregroundStyle(.red)
                } header: {
                    Text("Datos")
                } footer: {
                    Text("Limpia los datos almacenados localmente. Los favoritos no se eliminaran.")
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

                // Credits section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Datos proporcionados por:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            Image(systemName: "tram.fill")
                                .foregroundStyle(.cyan)
                            Text("RENFE Cercanias")
                        }

                        HStack {
                            Image(systemName: "tram.tunnel.fill")
                                .foregroundStyle(.red)
                            Text("Metro de Madrid")
                        }

                        HStack {
                            Image(systemName: "tram.tunnel.fill")
                                .foregroundStyle(.red)
                            Text("TMB Metro Barcelona")
                        }

                        HStack {
                            Image(systemName: "tram.fill")
                                .foregroundStyle(.purple)
                            Text("Rodalies de Catalunya")
                        }

                        HStack {
                            Image(systemName: "tram.fill")
                                .foregroundStyle(.orange)
                            Text("FGC")
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
        }
    }

    // MARK: - Developer Mode

    private func handleVersionTap() {
        versionTapCount += 1

        if versionTapCount >= 7 && !developerModeEnabled {
            developerModeEnabled = true
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }

        // Reset counter after 3 seconds of inactivity
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if versionTapCount < 7 {
                versionTapCount = 0
            }
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
        // Clear arrival cache
        URLCache.shared.removeAllCachedResponses()

        // Clear UserDefaults cache keys (but not favorites)
        let keysToRemove = ["lastLocationTimestamp", "lastLatitude", "lastLongitude"]
        for key in keysToRemove {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

#Preview {
    SettingsView()
}
