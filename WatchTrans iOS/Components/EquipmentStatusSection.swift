//
//  EquipmentStatusSection.swift
//  WatchTrans iOS
//
//  Generic equipment status view for elevators/escalators.
//  Works with any network (Metro Sevilla, Madrid, Barcelona, etc.)
//

import SwiftUI

struct EquipmentStatusSection: View {
    let equipment: [EquipmentStatusResponse]

    private var broken: [EquipmentStatusResponse] {
        equipment.filter { $0.isBroken }
    }

    private var working: [EquipmentStatusResponse] {
        equipment.filter { !$0.isBroken }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with count
            HStack {
                Image(systemName: "elevator.fill")
                    .foregroundStyle(.primary)
                Text("Accesos y equipos")
                    .font(.headline)
                Spacer()
                if !broken.isEmpty {
                    Text("\(broken.count) sin servicio")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            // Broken equipment first (always visible)
            ForEach(broken) { device in
                EquipmentRow(device: device)
            }

            // Working equipment in disclosure
            if !working.isEmpty {
                DisclosureGroup {
                    ForEach(working) { device in
                        EquipmentRow(device: device)
                    }
                } label: {
                    Text("\(working.count) operativo\(working.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Equipment Row

private struct EquipmentRow: View {
    let device: EquipmentStatusResponse

    /// Full descriptive name: "Ascensor - Calle" or "Escalera mecanica - Anden sentido Ciudad Expo"
    private var fullName: String {
        let type = device.isElevator ? "Ascensor" : "Escalera mecanica"
        if let location = device.location, !location.isEmpty {
            return "\(type) — \(location)"
        }
        return type
    }

    var body: some View {
        HStack(spacing: 8) {
            // Device icon (color matches status)
            Image(systemName: device.isElevator ? "elevator.fill" : "escalator")
                .font(.subheadline)
                .foregroundStyle(device.isBroken ? .red : .green)
                .frame(width: 20)

            // Full name
            Text(fullName)
                .font(.subheadline)
                .lineLimit(2)

            Spacer()

            // Status circle: green = operational, red = broken
            Circle()
                .fill(device.isBroken ? Color.red : Color.green)
                .frame(width: 10, height: 10)
        }
        .padding(.vertical, 2)
    }
}
