//
//  LinesView.swift
//  WatchTrans Watch App
//
//  Created by Juan Macias Gomez on 14/1/26.
//  Line browser - browse all networks from RenfeServer API
//

import SwiftUI

struct LinesView: View {
    let dataService: DataService
    let locationService: LocationService

    // Get Cercanías lines for the current nucleo only
    var cercaniasLines: [Line] {
        guard let currentNucleo = dataService.currentNucleo else {
            return []
        }

        return dataService.lines
            .filter { $0.type == .cercanias && $0.nucleo.lowercased() == currentNucleo.name.lowercased() }
            .sorted { lineNumber($0.name) < lineNumber($1.name) }
    }

    // Get Metro lines for the current nucleo
    var metroLines: [Line] {
        guard let currentNucleo = dataService.currentNucleo else {
            return []
        }

        return dataService.lines
            .filter { $0.type == .metro && $0.nucleo.lowercased() == currentNucleo.name.lowercased() }
            .sorted { lineNumber($0.name) < lineNumber($1.name) }
    }

    // Get Metro Ligero lines for the current nucleo
    var metroLigeroLines: [Line] {
        guard let currentNucleo = dataService.currentNucleo else {
            return []
        }

        return dataService.lines
            .filter { $0.type == .metroLigero && $0.nucleo.lowercased() == currentNucleo.name.lowercased() }
            .sorted { lineNumber($0.name) < lineNumber($1.name) }
    }

    // Extract numeric value from line name for proper sorting (C1, C2, C4a, C4b, C10, ML1, etc.)
    private func lineNumber(_ name: String) -> Double {
        let numericString = name.lowercased()
            .replacingOccurrences(of: "c", with: "")
            .replacingOccurrences(of: "r", with: "")  // For Rodalies
            .replacingOccurrences(of: "ml", with: "")  // For Metro Ligero
            .replacingOccurrences(of: "l", with: "")   // For Metro L prefix

        // Handle suffixes like "4a", "4b"
        if let lastChar = numericString.last, lastChar.isLetter {
            let number = Double(numericString.dropLast()) ?? 0
            // 'a' = 97, so 'a' -> 0.01, 'b' -> 0.02, etc.
            let suffix = Double(lastChar.asciiValue ?? 97) - 96.0
            return number + (suffix / 100.0)
        }

        return Double(numericString) ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 1. Cercanías Lines Section (first)
                if !cercaniasLines.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image("CercaniasLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 18)

                            Text("Cercanías")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                        ForEach(cercaniasLines) { line in
                            NavigationLink(destination: LineDetailView(line: line, dataService: dataService, locationService: locationService)) {
                                LineRowView(line: line)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // 2. Metro Lines Section
                if !metroLines.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image("MetroLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 14)  // Smaller height for diamond shape

                            Text("Metro")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                        ForEach(metroLines) { line in
                            NavigationLink(destination: LineDetailView(line: line, dataService: dataService, locationService: locationService)) {
                                LineRowView(line: line)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // 3. Metro Ligero Lines Section
                if !metroLigeroLines.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image("MetroLigeroLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 14)  // Smaller height for diamond shape

                            Text("Metro Ligero")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                        ForEach(metroLigeroLines) { line in
                            NavigationLink(destination: LineDetailView(line: line, dataService: dataService, locationService: locationService)) {
                                LineRowView(line: line)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Show loading or empty state
                if metroLines.isEmpty && metroLigeroLines.isEmpty && cercaniasLines.isEmpty {
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
        .navigationTitle(dataService.currentNucleo?.name ?? "Líneas")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Lines Section Component

struct LinesSectionView: View {
    let title: String
    let iconName: String
    let iconColor: Color
    let lines: [Line]
    let dataService: DataService
    let locationService: LocationService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            ForEach(lines) { line in
                NavigationLink(destination: LineDetailView(line: line, dataService: dataService, locationService: locationService)) {
                    LineRowView(line: line)
                }
                .buttonStyle(.plain)
            }
        }
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
