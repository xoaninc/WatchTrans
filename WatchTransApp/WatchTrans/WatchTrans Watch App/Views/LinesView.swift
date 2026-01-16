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

    // Get all Cercanías lines from the API (already filtered by nucleo)
    var cercaniasLines: [Line] {
        dataService.lines
            .filter { $0.type == .cercanias }
            .sorted { lineNumber($0.id) < lineNumber($1.id) }
    }

    // Extract numeric value from line ID for proper sorting
    private func lineNumber(_ id: String) -> Double {
        let numericString = id.uppercased()
            .replacingOccurrences(of: "C", with: "")

        // Handle suffixes like "4a", "4b"
        if let lastChar = numericString.last, lastChar.isLetter {
            let number = Double(numericString.dropLast()) ?? 0
            let suffix = Double(lastChar.asciiValue ?? 97) - 96.9
            return number + (suffix / 10.0)
        }

        return Double(numericString) ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Show detected nucleo info
                if let nucleo = dataService.currentNucleo {
                    NucleoHeaderView(nucleo: nucleo)
                }

                // Cercanías Lines Section
                if !cercaniasLines.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image("CercaniasLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 18)

                            Text("Cercanías Renfe")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                        ForEach(cercaniasLines) { line in
                            NavigationLink(destination: LineDetailView(line: line, dataService: dataService)) {
                                LineRowView(line: line)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else if dataService.isLoading {
                    ProgressView("Cargando líneas...")
                        .padding()
                } else {
                    Text("No hay líneas disponibles")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()
                }

                // Show all available nucleos for browsing
                if dataService.nucleos.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Otros núcleos")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.top, 16)

                        ForEach(dataService.nucleos.filter { $0.id != dataService.currentNucleo?.id }) { nucleo in
                            NucleoRowView(nucleo: nucleo)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
        }
        .navigationTitle("Líneas")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Nucleo Header Component

struct NucleoHeaderView: View {
    let nucleo: NucleoResponse

    var nucleoColor: Color {
        // Parse "R,G,B" format
        let components = nucleo.color.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        if components.count == 3 {
            return Color(red: components[0]/255, green: components[1]/255, blue: components[2]/255)
        }
        return .blue
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(nucleoColor)
                .frame(width: 12, height: 12)
            Text(nucleo.name)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(nucleo.linesCount) líneas")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }
}

// MARK: - Nucleo Row Component

struct NucleoRowView: View {
    let nucleo: NucleoResponse

    var nucleoColor: Color {
        let components = nucleo.color.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        if components.count == 3 {
            return Color(red: components[0]/255, green: components[1]/255, blue: components[2]/255)
        }
        return .blue
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(nucleoColor)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(nucleo.name.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(nucleo.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(nucleo.stationsCount) estaciones - \(nucleo.linesCount) líneas")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .cornerRadius(10)
    }
}

// MARK: - Line Row Component

struct LineRowView: View {
    let line: Line

    var lineColor: Color {
        Color(hex: line.colorHex) ?? .blue
    }

    // Adjust font size based on name length
    var badgeFontSize: CGFloat {
        line.name.count > 3 ? 13 : 16
    }

    // Abbreviate station name for compact display
    func abbreviateStation(_ name: String) -> String {
        var abbreviated = name

        // Remove city prefixes
        abbreviated = abbreviated.replacingOccurrences(of: "Madrid-", with: "")
        abbreviated = abbreviated.replacingOccurrences(of: "Sevilla-", with: "")
        abbreviated = abbreviated.replacingOccurrences(of: "Barcelona-", with: "")
        abbreviated = abbreviated.replacingOccurrences(of: "Valencia-", with: "")
        abbreviated = abbreviated.replacingOccurrences(of: "Málaga-", with: "")
        abbreviated = abbreviated.replacingOccurrences(of: "Bilbao-", with: "")

        // Shorten specific long station names first (most specific to least specific)
        abbreviated = abbreviated.replacingOccurrences(of: "Bilbao-Intermod. Abando Indalecio Prieto", with: "Abando")
        abbreviated = abbreviated.replacingOccurrences(of: "Alcobendas-San Sebastián De Los Reyes", with: "Alcobendas")
        abbreviated = abbreviated.replacingOccurrences(of: "Barcelona Estació De França", with: "Est. França")
        abbreviated = abbreviated.replacingOccurrences(of: "València-Estació Del Nord", with: "Est. Nord")
        abbreviated = abbreviated.replacingOccurrences(of: "Burriana-Alquerías Niño Perdido", with: "Burriana-Alq.")
        abbreviated = abbreviated.replacingOccurrences(of: "Estivella-Albalat Dels Tarongers", with: "Estivella-Alb.")
        abbreviated = abbreviated.replacingOccurrences(of: "Barcelona-La Sagrera-Meridiana", with: "La Sagrera")
        abbreviated = abbreviated.replacingOccurrences(of: "Les Franqueses-Granollers Nord", with: "Granollers N.")
        abbreviated = abbreviated.replacingOccurrences(of: "Benalmádena-Arroyo De La Miel", with: "Benalmádena")
        abbreviated = abbreviated.replacingOccurrences(of: "San Sebastián-Donostia", with: "Donostia")
        abbreviated = abbreviated.replacingOccurrences(of: "Universidad-Cantoblanco", with: "Univ-Canto")
        abbreviated = abbreviated.replacingOccurrences(of: "Chamartín-Clara Campoamor", with: "Chamrt")
        abbreviated = abbreviated.replacingOccurrences(of: "Villalba De Guadarrama", with: "Villalba Gua.")
        abbreviated = abbreviated.replacingOccurrences(of: "Barcelona-Passeig De Gràcia", with: "P. Gràcia")
        abbreviated = abbreviated.replacingOccurrences(of: "Barcelona-Plaça De Catalunya", with: "Pl. Catalunya")
        abbreviated = abbreviated.replacingOccurrences(of: "Castelló De La Plana", with: "Castelló P.")
        abbreviated = abbreviated.replacingOccurrences(of: "Alcalá De Henares", with: "Alcalá H.")

        // Shorten common words
        abbreviated = abbreviated.replacingOccurrences(of: "Aeropuerto", with: "Aerp")
        abbreviated = abbreviated.replacingOccurrences(of: "Príncipe Pío", with: "Prínc. Pío")
        abbreviated = abbreviated.replacingOccurrences(of: "Chamartín", with: "Chamrt")
        abbreviated = abbreviated.replacingOccurrences(of: "Universidad", with: "Univ")
        abbreviated = abbreviated.replacingOccurrences(of: "Estación", with: "Est")
        abbreviated = abbreviated.replacingOccurrences(of: "Estació", with: "Est.")
        abbreviated = abbreviated.replacingOccurrences(of: "Barcelona-", with: "Bcn-")
        abbreviated = abbreviated.replacingOccurrences(of: "Centro Alameda", with: "Ctr Alameda")
        abbreviated = abbreviated.replacingOccurrences(of: "Centro", with: "Ctr")
        abbreviated = abbreviated.replacingOccurrences(of: "Hospital", with: "Hosp.")
        abbreviated = abbreviated.replacingOccurrences(of: "Dos Hermanas", with: "Dos Herm.")
        abbreviated = abbreviated.replacingOccurrences(of: "Hermanas", with: "Herm.")
        abbreviated = abbreviated.replacingOccurrences(of: "Villanueva", with: "Vnva")
        abbreviated = abbreviated.replacingOccurrences(of: "Jardines", with: "Jard.")
        abbreviated = abbreviated.replacingOccurrences(of: "Virgen", with: "V.")
        abbreviated = abbreviated.replacingOccurrences(of: " De La ", with: " ")
        abbreviated = abbreviated.replacingOccurrences(of: " De Los ", with: " ")
        abbreviated = abbreviated.replacingOccurrences(of: " Del ", with: " ")
        abbreviated = abbreviated.replacingOccurrences(of: " De ", with: " ")
        abbreviated = abbreviated.replacingOccurrences(of: "Santa", with: "S.")
        abbreviated = abbreviated.replacingOccurrences(of: "Santo", with: "S.")
        abbreviated = abbreviated.replacingOccurrences(of: "San", with: "S.")
        abbreviated = abbreviated.replacingOccurrences(of: "Intermod.", with: "")

        // Truncate if still too long (max ~15 chars)
        if abbreviated.count > 15 {
            abbreviated = String(abbreviated.prefix(13)) + "."
        }

        return abbreviated.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Line badge
            Text(line.name)
                .font(.system(size: badgeFontSize, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, line.name.count > 3 ? 6 : 8)
                .padding(.vertical, 4)
                .frame(minWidth: 40)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(lineColor)
                )

            // Line info - nucleo name
            VStack(alignment: .leading, spacing: 2) {
                Text(line.nucleo.capitalized)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

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
