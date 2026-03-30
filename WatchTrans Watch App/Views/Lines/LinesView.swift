//
//  LinesView.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//  Line browser - browse all networks from WatchTrans API
//

import SwiftUI

/// Represents a group of lines belonging to one operator/network
struct LineSection: Identifiable {
    let id: String           // agencyId
    let name: String         // network name from API, fallback to agencyId
    let type: TransportType
    let lines: [Line]
}

struct LinesView: View {
    let dataService: DataService
    let locationService: LocationService

    // Current province name helper
    private var currentProvince: String? {
        dataService.currentLocation?.provinceName.lowercased()
    }

    // MARK: - Data-Driven Section Grouping

    /// Groups lines by agencyId and resolves display names from the networks API
    private var lineSections: [LineSection] {
        let province = currentProvince
        let filtered: [Line]
        if let province {
            filtered = dataService.lines.filter { $0.nucleo.lowercased() == province }
        } else {
            filtered = dataService.lines
        }

        let grouped = Dictionary(grouping: filtered) { $0.agencyId }
        let networks = dataService.currentLocation?.networks ?? []

        let sections = grouped.map { (agencyId, lines) -> LineSection in
            let networkName = lines.first?.agencyName
                ?? networks.first { $0.code == agencyId }?.name
                ?? agencyId
            let type = lines.first?.type ?? .tren
            return LineSection(
                id: agencyId,
                name: networkName,
                type: type,
                lines: lines.sorted { compareLineWithType($0, $1) }
            )
        }

        return sections.sorted { a, b in
            let aOrder = transportTypeOrder(a.type)
            let bOrder = transportTypeOrder(b.type)
            if aOrder != bOrder { return aOrder < bOrder }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    /// Sorting priority for transport types
    private func transportTypeOrder(_ type: TransportType) -> Int {
        switch type {
        case .tren: return 0
        case .metro: return 1
        case .tram: return 2
        case .bus: return 3
        case .funicular: return 4
        }
    }

    // Extract sort key for line names
    // Returns (prefixOrder, number) for proper sorting
    // Cercanías/Rodalies: C/R → RG → RT
    // Metro: L (numeric) → LFM (funicular last)
    // FGC: L → S → R → RL → MM → FV
    // Tram: T
    private func lineSortKey(_ name: String, type: TransportType? = nil) -> (Int, Double) {
        let lowered = name.lowercased()

        // Determine prefix order (lower = first)
        let prefixOrder: Int
        let numericPart: String

        // Special handling for FGC lines
        if type == .tren {
            if lowered.hasPrefix("l") {
                prefixOrder = 1  // L lines first (urban)
                numericPart = String(lowered.dropFirst(1))
            } else if lowered.hasPrefix("s") {
                prefixOrder = 2  // S lines (suburban)
                numericPart = String(lowered.dropFirst(1))
            } else if lowered.hasPrefix("rl") {
                prefixOrder = 4  // RL lines after R
                numericPart = String(lowered.dropFirst(2))
            } else if lowered.hasPrefix("r") {
                prefixOrder = 3  // R lines (regional)
                numericPart = String(lowered.dropFirst(1))
            } else if lowered == "mm" {
                prefixOrder = 8  // MetroVallesana
                numericPart = "0"
            } else if lowered == "fv" {
                prefixOrder = 9  // Funicular Vallvidrera
                numericPart = "0"
            } else {
                prefixOrder = 10
                numericPart = lowered
            }
        }
        // Special handling for Metro lines
        else if type == .metro {
            if lowered == "lfm" || lowered == "fm" {
                prefixOrder = 9  // Funicular Montjuïc last
                numericPart = "0"
            } else if lowered.hasPrefix("l") {
                prefixOrder = 1  // L lines
                numericPart = String(lowered.dropFirst(1))
            } else {
                prefixOrder = 5
                numericPart = lowered
            }
        }
        // Cercanías/Rodalies
        else if lowered.hasPrefix("rg") {
            prefixOrder = 2  // RG after R
            numericPart = String(lowered.dropFirst(2))
        } else if lowered.hasPrefix("rt") {
            prefixOrder = 3  // RT after RG
            numericPart = String(lowered.dropFirst(2))
        } else if lowered.hasPrefix("rl") {
            prefixOrder = 4  // RL after RT
            numericPart = String(lowered.dropFirst(2))
        } else if lowered.hasPrefix("r") {
            prefixOrder = 1  // R first (Rodalies)
            numericPart = String(lowered.dropFirst(1))
        } else if lowered.hasPrefix("c") {
            prefixOrder = 1  // C same as R (Cercanías)
            numericPart = String(lowered.dropFirst(1))
        } else if lowered.hasPrefix("s") {
            prefixOrder = 5  // S lines
            numericPart = String(lowered.dropFirst(1))
        } else if lowered.hasPrefix("ml") {
            prefixOrder = 6  // ML (Metro Ligero)
            numericPart = String(lowered.dropFirst(2))
        } else if lowered.hasPrefix("l") {
            prefixOrder = 5  // L (Metro)
            numericPart = String(lowered.dropFirst(1))
        } else if lowered.hasPrefix("t") {
            prefixOrder = 7  // T (Tram)
            numericPart = String(lowered.dropFirst(1))
        } else {
            prefixOrder = 10  // Other
            numericPart = lowered
        }

        // Parse numeric value with suffix handling (4a, 4b, 7b, 9n, 9s, 10n, 10s, etc.)
        var numberStr = numericPart
        var suffixValue: Double = 0

        // Handle suffix letters (a, b, n, s)
        if let lastChar = numberStr.last, lastChar.isLetter {
            numberStr = String(numberStr.dropLast())
            // n=0.01, s=0.02 for metro splits, a/b for branches
            switch lastChar {
            case "n": suffixValue = 0.01
            case "s": suffixValue = 0.02
            default: suffixValue = (Double(lastChar.asciiValue ?? 97) - 96.0) / 100.0
            }
        }

        let number = Double(numberStr) ?? 0
        return (prefixOrder, number + suffixValue)
    }

    // Compare two Line objects for sorting (with type info for better sorting)
    private func compareLineWithType(_ a: Line, _ b: Line) -> Bool {
        let keyA = lineSortKey(a.name, type: a.type)
        let keyB = lineSortKey(b.name, type: b.type)

        if keyA.0 != keyB.0 {
            return keyA.0 < keyB.0  // Sort by prefix first
        }
        return keyA.1 < keyB.1  // Then by number
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Debug: Log sections on appear
                Color.clear.frame(height: 0).onAppear {
                    let province = dataService.currentLocation?.provinceName ?? "unknown"
                    DebugLog.log("📋 [LinesView] ========== LINES VIEW ==========")
                    DebugLog.log("📋 [LinesView] Province: '\(province)'")
                    DebugLog.log("📋 [LinesView] currentProvince (lowercased): '\(currentProvince ?? "nil")'")
                    DebugLog.log("📋 [LinesView] Total lines in dataService: \(dataService.lines.count)")

                    let sections = lineSections
                    DebugLog.log("📋 [LinesView] Sections: \(sections.count)")
                    for section in sections {
                        DebugLog.log("📋 [LinesView]   \(section.name) (\(section.id)): \(section.lines.count) lines")
                    }
                }

                ForEach(lineSections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            LogoImageView(type: section.type, height: 14)
                            Text(section.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                        ForEach(section.lines) { line in
                            NavigationLink(destination: LineDetailView(line: line, dataService: dataService, locationService: locationService)) {
                                LineRowView(line: line)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Show loading or empty state
                if lineSections.isEmpty {
                    if dataService.isLoading {
                        ProgressView("Cargando líneas...")
                            .padding()
                    } else {
                        Text("No hay líneas disponibles")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                }

            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
        }
        .navigationTitle(dataService.currentLocation?.provinceName ?? "Líneas")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Line Row Component

struct LineRowView: View {
    let line: Line

    // Responsive font size that scales with watch size
    @ScaledMetric(relativeTo: .caption2) private var descriptionFontSize: CGFloat = 11

    var lineColor: Color {
        Color(hex: line.colorHex) ?? .blue
    }

    // Adjust font size based on name length
    var badgeFontSize: CGFloat {
        switch line.name.count {
        case 1...2: return 16
        case 3: return 14
        default: return 12
        }
    }

    var badgeMinWidth: CGFloat {
        switch line.name.count {
        case 1...2: return 40
        case 3: return 48
        default: return 55
        }
    }

    // Abbreviate line description for compact watchOS display
    func abbreviateLine(_ name: String) -> String {
        var abbreviated = name

        // Metro specific abbreviations
        abbreviated = abbreviated.replacingOccurrences(of: "Pinar de Chamartín", with: "P. Chamartín")
        abbreviated = abbreviated.replacingOccurrences(of: "Hospital Infanta Sofía", with: "H. Inf. Sofía")
        abbreviated = abbreviated.replacingOccurrences(of: "Puerta del Sur", with: "Pta. Sur")
        abbreviated = abbreviated.replacingOccurrences(of: "Plaza Elíptica", with: "Pza. Elíptica")
        abbreviated = abbreviated.replacingOccurrences(of: "La Fortuna", with: "La Fortuna")
        abbreviated = abbreviated.replacingOccurrences(of: "MetroSur (Circular)", with: "Circular")
        abbreviated = abbreviated.replacingOccurrences(of: "Las Rosas", with: "Las Rosas")
        abbreviated = abbreviated.replacingOccurrences(of: "Cuatro Caminos", with: "4 Caminos")
        abbreviated = abbreviated.replacingOccurrences(of: "El Casar", with: "El Casar")
        abbreviated = abbreviated.replacingOccurrences(of: "Alameda de Osuna", with: "Almd. Osuna")
        abbreviated = abbreviated.replacingOccurrences(of: "Casa de Campo", with: "Casa Campo")
        abbreviated = abbreviated.replacingOccurrences(of: "Hospital del Henares", with: "H. Henares")
        abbreviated = abbreviated.replacingOccurrences(of: "Nuevos Ministerios", with: "Nvos. Minist.")
        abbreviated = abbreviated.replacingOccurrences(of: "Aeropuerto T4", with: "Aerp. T4")
        abbreviated = abbreviated.replacingOccurrences(of: "Paco de Lucía", with: "Paco Lucía")
        abbreviated = abbreviated.replacingOccurrences(of: "Arganda del Rey", with: "Arganda")
        abbreviated = abbreviated.replacingOccurrences(of: "Príncipe Pío", with: "P. Pío")

        // Metro Ligero specific abbreviations
        abbreviated = abbreviated.replacingOccurrences(of: "Las Tablas", with: "Las Tablas")
        abbreviated = abbreviated.replacingOccurrences(of: "Colonia Jardín", with: "Col. Jardín")
        abbreviated = abbreviated.replacingOccurrences(of: "Estación de Aravaca", with: "Est. Aravaca")
        abbreviated = abbreviated.replacingOccurrences(of: "Puerta de Boadilla", with: "Pta. Boadilla")
        abbreviated = abbreviated.replacingOccurrences(of: "Tranvía de Parla (Circular)", with: "Parla Circular")

        // Remove city prefixes
        abbreviated = abbreviated.replacingOccurrences(of: "Madrid-", with: "")
        abbreviated = abbreviated.replacingOccurrences(of: "Sevilla-", with: "")
        abbreviated = abbreviated.replacingOccurrences(of: "Barcelona-", with: "")
        abbreviated = abbreviated.replacingOccurrences(of: "Valencia-", with: "")
        abbreviated = abbreviated.replacingOccurrences(of: "Málaga-", with: "")
        abbreviated = abbreviated.replacingOccurrences(of: "Bilbao-", with: "")

        // Specific long station names (most specific first)
        abbreviated = abbreviated.replacingOccurrences(of: "Chamartín-Clara Campoamor", with: "Chamartín")
        abbreviated = abbreviated.replacingOccurrences(of: "Alcobendas-San Sebastián de los Reyes", with: "Alcobendas")
        abbreviated = abbreviated.replacingOccurrences(of: "València Estació del Nord", with: "València Nord")
        abbreviated = abbreviated.replacingOccurrences(of: "Castelló de la Plana", with: "Castelló")
        abbreviated = abbreviated.replacingOccurrences(of: "Gijón Sanz Crespo", with: "Gijón")
        abbreviated = abbreviated.replacingOccurrences(of: "Murcia del Carmen", with: "Murcia")
        abbreviated = abbreviated.replacingOccurrences(of: "Alacant Terminal", with: "Alacant")
        abbreviated = abbreviated.replacingOccurrences(of: "Santa María de la Alameda", with: "Sta.Mª Alameda")
        abbreviated = abbreviated.replacingOccurrences(of: "Cazalla-Constantina", with: "Cazalla-Const.")
        abbreviated = abbreviated.replacingOccurrences(of: "Villalba de Guadarrama", with: "Villalba")
        abbreviated = abbreviated.replacingOccurrences(of: "Alcalá de Henares", with: "Alcalá H.")
        abbreviated = abbreviated.replacingOccurrences(of: "San Juan de Nieva", with: "S.Juan Nieva")
        abbreviated = abbreviated.replacingOccurrences(of: "Puente de los Fierros", with: "Pte. Fierros")
        abbreviated = abbreviated.replacingOccurrences(of: "Aeropuerto de Jerez", with: "Aerp. Jerez")
        abbreviated = abbreviated.replacingOccurrences(of: "Benalmádena-Arroyo de la Miel", with: "Benalmádena")
        abbreviated = abbreviated.replacingOccurrences(of: "Barcelona Estació de França", with: "Est. França")
        abbreviated = abbreviated.replacingOccurrences(of: "Barcelona-Passeig de Gràcia", with: "P. Gràcia")
        abbreviated = abbreviated.replacingOccurrences(of: "Barcelona-Plaça de Catalunya", with: "Pl. Catalunya")
        abbreviated = abbreviated.replacingOccurrences(of: "Barcelona-La Sagrera-Meridiana", with: "La Sagrera")
        abbreviated = abbreviated.replacingOccurrences(of: "Bilbao-Intermod. Abando Indalecio Prieto", with: "Abando")
        abbreviated = abbreviated.replacingOccurrences(of: "Bilbao La Concordia", with: "La Concordia")
        abbreviated = abbreviated.replacingOccurrences(of: "San Sebastián-Donostia", with: "Donostia")
        abbreviated = abbreviated.replacingOccurrences(of: "Sant Vicent Centre", with: "Sant Vicent")
        abbreviated = abbreviated.replacingOccurrences(of: "Móstoles-El Soto", with: "Móstoles")
        abbreviated = abbreviated.replacingOccurrences(of: "Infiesto Apeadero", with: "Infiesto")
        abbreviated = abbreviated.replacingOccurrences(of: "Moixent/Mogente", with: "Moixent")
        abbreviated = abbreviated.replacingOccurrences(of: "Málaga Centro", with: "Málaga Ctr.")
        abbreviated = abbreviated.replacingOccurrences(of: "Lora del Río", with: "Lora Río")
        abbreviated = abbreviated.replacingOccurrences(of: "San Esteban", with: "S. Esteban")
        abbreviated = abbreviated.replacingOccurrences(of: "Dos Hermanas", with: "Dos Herm.")

        // Common station names
        abbreviated = abbreviated.replacingOccurrences(of: "Guadalajara", with: "Guadljr.")
        abbreviated = abbreviated.replacingOccurrences(of: "Chamartín", with: "Chamrt.")

        // Common words
        abbreviated = abbreviated.replacingOccurrences(of: "Aeropuerto", with: "Aerp.")
        abbreviated = abbreviated.replacingOccurrences(of: "Príncipe Pío", with: "P. Pío")
        abbreviated = abbreviated.replacingOccurrences(of: "Universidad", with: "Univ.")
        abbreviated = abbreviated.replacingOccurrences(of: "Estación", with: "Est.")
        abbreviated = abbreviated.replacingOccurrences(of: "Estació", with: "Est.")
        abbreviated = abbreviated.replacingOccurrences(of: "Centro", with: "Ctr.")
        abbreviated = abbreviated.replacingOccurrences(of: "Hospital", with: "Hosp.")
        abbreviated = abbreviated.replacingOccurrences(of: "Terminal", with: "Term.")
        abbreviated = abbreviated.replacingOccurrences(of: "Apeadero", with: "Aped.")
        abbreviated = abbreviated.replacingOccurrences(of: " de la ", with: " ")
        abbreviated = abbreviated.replacingOccurrences(of: " de los ", with: " ")
        abbreviated = abbreviated.replacingOccurrences(of: " del ", with: " ")
        abbreviated = abbreviated.replacingOccurrences(of: " de ", with: " ")
        abbreviated = abbreviated.replacingOccurrences(of: "Santa ", with: "Sta. ")
        abbreviated = abbreviated.replacingOccurrences(of: "Santo ", with: "Sto. ")
        abbreviated = abbreviated.replacingOccurrences(of: "San ", with: "S. ")

        // No truncation - let SwiftUI handle text wrapping based on screen size
        return abbreviated.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Line badge
            Text(line.name)
                .font(.system(size: badgeFontSize, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .frame(minWidth: badgeMinWidth)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(lineColor)
                )

            // Line info - terminus stations (abbreviated for watchOS)
            Text(abbreviateLine(line.longName))
                .font(.system(size: descriptionFontSize))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .cornerRadius(10)
    }
}

#Preview {
    NavigationStack {
        LinesView(dataService: DataService(), locationService: LocationService())
    }
}
