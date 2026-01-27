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
                    if let websiteURL = URL(string: "https://redcercanias.com") {
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

                    if let privacyURL = URL(string: "https://github.com/xoaninc/WatchTrans/blob/main/PRIVACY_POLICY.md") {
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
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Ajustes")
        }
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
