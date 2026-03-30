//
//  LogoImageView.swift
//  WatchTrans Watch App
//
//  Fallback icon based on TransportType.
//  When the API provides a logo field, this will load remote logos.
//

import SwiftUI

struct LogoImageView: View {
    let height: CGFloat
    private let assetName: String

    init(type: TransportType, height: CGFloat) {
        self.height = height
        switch type {
        case .metro: self.assetName = "MetroSymbol"
        case .tren: self.assetName = "TrenSymbol"
        case .tram: self.assetName = "TramSymbol"
        case .bus: self.assetName = "BusSymbol"
        case .funicular: self.assetName = "FunicularSymbol"
        }
    }

    var body: some View {
        SymbolView(name: assetName, size: height * 0.8)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    VStack(spacing: 20) {
        LogoImageView(type: .tren, height: 20)
        LogoImageView(type: .metro, height: 20)
        LogoImageView(type: .tram, height: 20)
    }
}
