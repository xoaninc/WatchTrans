//
//  LineBadgeView.swift
//  WatchTrans iOS
//
//  Created by Juan Macias Gomez on 21/1/26.
//

import SwiftUI

struct LineBadgeView: View {
    let name: String
    let color: Color

    var body: some View {
        Text(name)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
            )
    }
}

// Line badge that automatically gets color from dataService
struct LineAutoColorBadgeView: View {
    let lineId: String
    let dataService: DataService

    var lineColor: Color {
        if let line = dataService.getLine(by: lineId),
           let color = Color(hex: line.colorHex) {
            return color
        }
        return .blue
    }

    var lineName: String {
        dataService.getLine(by: lineId)?.name ?? lineId.uppercased()
    }

    var body: some View {
        LineBadgeView(name: lineName, color: lineColor)
    }
}

#Preview {
    HStack {
        LineBadgeView(name: "C3", color: .purple)
        LineBadgeView(name: "L1", color: .cyan)
        LineBadgeView(name: "ML1", color: .blue)
    }
    .padding()
}
