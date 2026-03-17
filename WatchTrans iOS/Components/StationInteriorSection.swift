//
//  StationInteriorSection.swift
//  WatchTrans iOS
//
//  Shows station interior: accesses, pathways, vestibules, and levels.
//  Generic — works with any network that has station-interior data.
//

import SwiftUI

struct StationInteriorSection: View {
    let interior: StationInteriorResponse

    private var accesses: [InteriorAccess] { interior.accesses ?? [] }
    private var pathways: [InteriorPathway] { interior.pathways ?? [] }
    private var vestibules: [StationVestibule] { interior.vestibules ?? [] }
    private var levels: [StationLevel] { interior.levels ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "building.2")
                    .foregroundStyle(.blue)
                Text("Interior de estacion")
                    .font(.headline)
                Spacer()
            }

            // Accesos
            if !accesses.isEmpty {
                AccessesSubsection(accesses: accesses)
            }

            // Recorridos
            if !pathways.isEmpty {
                PathwaysSubsection(pathways: pathways)
            }

            // Vestibulos
            if !vestibules.isEmpty {
                VestibulesSubsection(vestibules: vestibules)
            }

            // Niveles
            if !levels.isEmpty {
                LevelsSubsection(levels: levels)
            }
        }
    }
}

// MARK: - Accesos Subsection

private struct AccessesSubsection: View {
    let accesses: [InteriorAccess]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Accesos")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(accesses.prefix(3)) { access in
                AccessRow(access: access)
            }

            if accesses.count > 3 {
                DisclosureGroup {
                    ForEach(accesses.dropFirst(3)) { access in
                        AccessRow(access: access)
                    }
                } label: {
                    Text("\(accesses.count - 3) mas")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Access Row

private struct AccessRow: View {
    let access: InteriorAccess

    private var streetText: String? {
        var parts: [String] = []
        if let street = access.street, !street.isEmpty {
            parts.append(street)
        }
        if let number = access.streetNumber, !number.isEmpty {
            parts.append(number)
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private var isAccessible: Bool { access.wheelchair == true }

    var body: some View {
        HStack(spacing: 8) {
            if isAccessible {
                Image("ElevatorSymbol")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.green)
                    .frame(width: 20)
            } else {
                Image(systemName: "door.left.hand.open")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(access.name ?? "Acceso")
                    .font(.subheadline)
                if let street = streetText {
                    Text(street)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isAccessible {
                Text("Accesible")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Pathways Subsection

private struct PathwaysSubsection: View {
    let pathways: [InteriorPathway]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Recorridos")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(pathways.prefix(5)) { pathway in
                PathwayRow(pathway: pathway)
            }

            if pathways.count > 5 {
                DisclosureGroup {
                    ForEach(pathways.dropFirst(5)) { pathway in
                        PathwayRow(pathway: pathway)
                    }
                } label: {
                    Text("\(pathways.count - 5) mas")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Pathway Row

private struct PathwayRow: View {
    let pathway: InteriorPathway

    /// signposted_as if available, otherwise "from → to"
    private var displayText: String {
        if let sign = pathway.signpostedAs, !sign.isEmpty {
            return sign
        }
        let from = pathway.fromStopName ?? "?"
        let to = pathway.toStopName ?? "?"
        return "\(from) → \(to)"
    }

    private var modeIcon: String {
        switch pathway.pathwayModeName {
        case "stairs": return "figure.stairs"
        case "elevator": return "arrow.up.arrow.down"
        case "escalator": return "arrow.up.right"
        default: return "figure.walk"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: modeIcon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(displayText)
                .font(.subheadline)
                .lineLimit(2)

            Spacer()

            if let time = pathway.traversalTime {
                Text("\(time)s")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Vestibules Subsection

private struct VestibulesSubsection: View {
    let vestibules: [StationVestibule]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Vestibulos")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(vestibules) { vestibule in
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.split.3x1")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(vestibule.name ?? "Vestibulo")
                            .font(.subheadline)
                        if let level = vestibule.level {
                            Text("Nivel \(level)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if vestibule.wheelchair == true {
                        Text("Accesible")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

// MARK: - Levels Subsection

private struct LevelsSubsection: View {
    let levels: [StationLevel]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Plantas")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(levels.sorted(by: { ($0.index ?? 0) > ($1.index ?? 0) })) { level in
                HStack(spacing: 8) {
                    Text(levelLabel(level.index))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .frame(width: 30)
                    Text(level.name ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func levelLabel(_ index: Double?) -> String {
        guard let index = index else { return "?" }
        if index == 0 { return "PB" }
        if index > 0 { return "+\(Int(index))" }
        return "\(Int(index))"
    }
}
