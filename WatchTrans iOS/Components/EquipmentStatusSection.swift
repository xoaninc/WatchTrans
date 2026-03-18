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
            // Header
            HStack {
                Image(systemName: "figure.roll")
                    .foregroundStyle(.blue)
                Text("Accesibilidad")
                    .font(.headline)
                Spacer()
                if !broken.isEmpty {
                    Text("\(broken.count) sin servicio")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            // All equipment in a single disclosure group
            DisclosureGroup {
                // Broken first (red)
                ForEach(broken) { device in
                    EquipmentRow(device: device)
                }
                // Working after (green)
                ForEach(working) { device in
                    EquipmentRow(device: device)
                }
            } label: {
                if !broken.isEmpty && !working.isEmpty {
                    Text("\(broken.count) sin servicio · \(working.count) operativo\(working.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if !broken.isEmpty {
                    Text("\(broken.count) sin servicio")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
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

    private var statusColor: Color {
        device.isBroken ? .red : .green
    }

    /// Location only — the icon already tells the type
    private var locationText: String {
        device.location ?? (device.isElevator ? "Ascensor" : "Escalera")
    }

    var body: some View {
        HStack(spacing: 8) {
            // Device icon with status color
            if device.isElevator {
                Image("ElevatorSymbol")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(statusColor)
            } else {
                HStack(spacing: 2) {
                    Image("EscalatorSymbol")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(statusColor)
                    if let dir = device.direction, dir == "up" || dir == "down" {
                        Image(systemName: dir == "up" ? "arrow.up" : "arrow.down")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(statusColor)
                    }
                }
            }

            // Location
            Text(locationText)
                .font(.subheadline)
                .lineLimit(2)

            Spacer()

            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
        }
        .padding(.vertical, 2)
    }
}
