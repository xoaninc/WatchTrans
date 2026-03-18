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
    var operatingHours: DayOperatingHours?

    private var broken: [EquipmentStatusResponse] {
        equipment.filter { $0.isBroken }
    }

    private var working: [EquipmentStatusResponse] {
        equipment.filter { !$0.isBroken }
    }

    /// All equipment is marked as broken and we're outside operating hours → nightly shutdown
    private var isNightlyShutdown: Bool {
        guard working.isEmpty, !broken.isEmpty else { return false }
        guard let hours = operatingHours else { return false }
        return !isWithinOperatingHours(hours)
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
                if isNightlyShutdown {
                    Text("Metro cerrado")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !broken.isEmpty {
                    Text("\(broken.count) sin servicio")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if isNightlyShutdown {
                HStack(spacing: 8) {
                    Image(systemName: "moon.zzz.fill")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Equipos apagados por cierre nocturno")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let hours = operatingHours {
                            Text("Horario: \(hours.displayString)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.vertical, 4)
            } else {
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

    /// Check if current time falls within operating hours (handles overnight like 06:30-02:38)
    private func isWithinOperatingHours(_ hours: DayOperatingHours) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        guard let nowMinutes = nowComponents.hour.map({ $0 * 60 + (nowComponents.minute ?? 0) }) else { return true }

        let startMinutes = parseTimeToMinutes(hours.firstDeparture)
        let endMinutes = parseTimeToMinutes(hours.lastDeparture)

        // Handle overnight (e.g., 06:30-26:38 → 06:30-02:38 next day)
        if endMinutes > 24 * 60 {
            // Overnight service: open from startMinutes until endMinutes-1440 next day
            let adjustedEnd = endMinutes - 24 * 60
            return nowMinutes >= startMinutes || nowMinutes <= adjustedEnd
        }

        return nowMinutes >= startMinutes && nowMinutes <= endMinutes
    }

    /// Parse "HH:mm:ss" to minutes since midnight (supports >24h like "26:38:30")
    private func parseTimeToMinutes(_ time: String) -> Int {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return 0 }
        return parts[0] * 60 + parts[1]
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
