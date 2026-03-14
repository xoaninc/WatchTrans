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
                Image(systemName: "arrow.up.arrow.down")
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

    /// Location only — the icon already tells the type (elevator/escalator)
    private var locationText: String {
        device.location ?? (device.isElevator ? "Ascensor" : "Escalera")
    }

    var body: some View {
        HStack(spacing: 8) {
            // Device icon (color matches status, escalator shows direction arrow)
            HStack(spacing: 2) {
                Image(systemName: device.isElevator ? "arrow.up.arrow.down" : "stairs")
                    .font(.subheadline)
                    .foregroundStyle(device.isBroken ? .red : .green)
                if device.isEscalator, let dir = device.direction, dir == "up" || dir == "down" {
                    Image(systemName: dir == "up" ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(device.isBroken ? .red : .green)
                }
            }
            .frame(width: 30)

            // Location
            Text(locationText)
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
