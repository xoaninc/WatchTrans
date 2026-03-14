//
//  StopAlertBadge.swift
//  WatchTrans iOS
//
//  Created by Juan Macias Gomez on 14/3/26.
//

import SwiftUI

struct StopAlertBadge: View {
    let alerts: [AlertResponse]
    let mode: DisplayMode

    enum DisplayMode {
        case dot      // Small colored dot (HomeView)
        case inline   // Icon + short text (LineDetailView)
    }

    private var topAlert: AlertResponse? {
        // Priority: NO_SERVICE > ACCESSIBILITY_ISSUE > MODIFIED_SERVICE > SIGNIFICANT_DELAYS > REDUCED_SERVICE
        let priority = ["NO_SERVICE", "ACCESSIBILITY_ISSUE", "MODIFIED_SERVICE", "SIGNIFICANT_DELAYS", "REDUCED_SERVICE"]
        return alerts.min { a, b in
            let aIdx = priority.firstIndex(of: a.effect ?? "") ?? priority.count
            let bIdx = priority.firstIndex(of: b.effect ?? "") ?? priority.count
            return aIdx < bIdx
        }
    }

    private var alertColor: Color {
        switch topAlert?.effect {
        case "NO_SERVICE": return .red
        case "ACCESSIBILITY_ISSUE", "SIGNIFICANT_DELAYS": return .orange
        case "MODIFIED_SERVICE", "REDUCED_SERVICE": return .yellow
        default: return .orange
        }
    }

    private var alertIcon: String {
        switch topAlert?.effect {
        case "NO_SERVICE": return "xmark.circle.fill"
        case "ACCESSIBILITY_ISSUE": return "figure.roll"
        case "MODIFIED_SERVICE": return "exclamationmark.triangle.fill"
        case "SIGNIFICANT_DELAYS": return "clock.badge.exclamationmark"
        case "REDUCED_SERVICE": return "arrow.down.circle"
        default: return "exclamationmark.triangle.fill"
        }
    }

    private var shortText: String {
        guard let alert = topAlert else { return "" }
        // Use header_text truncated, or a default by effect
        if let header = alert.headerText, header.count <= 40 {
            return header
        }
        switch alert.effect {
        case "NO_SERVICE": return "Servicio suspendido"
        case "ACCESSIBILITY_ISSUE": return "Accesibilidad reducida"
        case "MODIFIED_SERVICE": return "Servicio modificado"
        case "SIGNIFICANT_DELAYS": return "Retrasos significativos"
        case "REDUCED_SERVICE": return "Frecuencia reducida"
        default: return "Alerta activa"
        }
    }

    var body: some View {
        if alerts.isEmpty { EmptyView() }
        else {
            switch mode {
            case .dot:
                Circle()
                    .fill(alertColor)
                    .frame(width: 8, height: 8)
            case .inline:
                HStack(spacing: 4) {
                    Image(systemName: alertIcon)
                        .font(.caption2)
                        .foregroundStyle(alertColor)
                    Text(shortText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}
