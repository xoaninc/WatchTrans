//
//  SymbolView.swift
//  WatchTrans iOS
//
//  Reusable views for rendering custom pictogram assets (ISO 7001, AIGA).
//

import SwiftUI

/// Renders a custom asset symbol with consistent sizing and template rendering.
struct SymbolView: View {
    let name: String
    var size: CGFloat = 16

    var body: some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

/// Renders a custom asset symbol with a Red Cross overlay indicating "is NOT".
/// Example: WheelchairSymbol + Red Cross = train is NOT wheelchair accessible.
/// NOT for "out of service" (use red foregroundStyle) or "doesn't exist" (show no icon).
struct NegatedSymbolView: View {
    let name: String
    var size: CGFloat = 16

    var body: some View {
        ZStack {
            SymbolView(name: name, size: size)
            SymbolView(name: "RedCrossOverlay", size: size)
        }
    }
}
