//
//  OfflineBanner.swift
//  WatchTrans Watch App
//
//  Created by Claude on 17/1/26.
//  Banner shown when device is offline
//

import SwiftUI

struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi.slash")
                .font(.caption)

            Text("Sin conexión")
                .font(.caption)
                .fontWeight(.medium)

            Spacer()

            Text("Datos en caché")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.8))
        )
        .padding(.horizontal, 8)
    }
}

/// Compact version for smaller spaces
struct OfflineBannerCompact: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "wifi.slash")
                .font(.caption2)
            Text("Offline")
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.gray.opacity(0.3))
        )
    }
}

/// Stale data indicator (when showing cached data)
struct StaleDataBanner: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.caption)

            Text("Datos guardados")
                .font(.caption)
                .fontWeight(.medium)

            Spacer()

            Text("Actualizando...")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.15))
        )
        .padding(.horizontal, 8)
    }
}

#Preview {
    VStack(spacing: 16) {
        OfflineBanner()
        OfflineBannerCompact()
        StaleDataBanner()
    }
    .padding()
}
