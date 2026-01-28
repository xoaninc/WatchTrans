//
//  LinesListView.swift
//  WatchTrans iOS
//
//  Created by Juan Macias Gomez on 21/1/26.
//

import SwiftUI

struct LinesListView: View {
    let dataService: DataService
    let locationService: LocationService

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
            List {
                // Cercanias/Rodalies section
                if !cercaniasLines.isEmpty {
                    Section {
                        ForEach(cercaniasLines) { line in
                            NavigationLink(destination: LineDetailView(
                                line: line,
                                dataService: dataService,
                                locationService: locationService
                            )) {
                                LineRowView(line: line)
                            }
                        }
                    } header: {
                        HStack(spacing: 8) {
                            LogoImageView(
                                logoType: isRodalies ? .rodalies : .cercanias,
                                height: 22
                            )
                            Text(isRodalies ? "Rodalies" : "Cercanías")
                        }
                    }
                }

                // Metro section
                if !metroLines.isEmpty {
                    Section {
                        ForEach(metroLines) { line in
                            NavigationLink(destination: LineDetailView(
                                line: line,
                                dataService: dataService,
                                locationService: locationService
                            )) {
                                LineRowView(line: line)
                            }
                        }
                    } header: {
                        HStack(spacing: 8) {
                            LogoImageView(
                                logoType: .metro(nucleo: dataService.currentLocation?.provinceName ?? "Madrid"),
                                height: 18
                            )
                            Text(metroSectionTitle)
                        }
                    }
                }

                // Metro Ligero section
                if !metroLigeroLines.isEmpty {
                    Section {
                        ForEach(metroLigeroLines) { line in
                            NavigationLink(destination: LineDetailView(
                                line: line,
                                dataService: dataService,
                                locationService: locationService
                            )) {
                                LineRowView(line: line)
                            }
                        }
                    } header: {
                        HStack(spacing: 8) {
                            LogoImageView(
                                logoType: .metroLigero,
                                height: 18
                            )
                            Text("Metro Ligero")
                        }
                    }
                }

                // Tram section
                if !tramLines.isEmpty {
                    Section {
                        ForEach(tramLines) { line in
                            NavigationLink(destination: LineDetailView(
                                line: line,
                                dataService: dataService,
                                locationService: locationService
                            )) {
                                LineRowView(line: line)
                            }
                        }
                    } header: {
                        HStack(spacing: 8) {
                            LogoImageView(
                                logoType: .tram(nucleo: dataService.currentLocation?.provinceName ?? ""),
                                height: 18
                            )
                            Text(tramSectionTitle)
                        }
                    }
                }

                // FGC section (Barcelona only)
                if !fgcLines.isEmpty {
                    Section {
                        ForEach(fgcLines) { line in
                            NavigationLink(destination: LineDetailView(
                                line: line,
                                dataService: dataService,
                                locationService: locationService
                            )) {
                                LineRowView(line: line)
                            }
                        }
                    } header: {
                        HStack(spacing: 8) {
                            LogoImageView(
                                logoType: .fgc,
                                height: 22
                            )
                            Text("Ferrocarrils (FGC)")
                        }
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
            .task {
                // Cache line itineraries for offline use when in a province
                await cacheItinerariesIfNeeded()
            }
        }
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

    var body: some View {
        HStack(spacing: 12) {
            // Line badge
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

#Preview {
    LinesListView(
        dataService: DataService(),
        locationService: LocationService()
    )
}
