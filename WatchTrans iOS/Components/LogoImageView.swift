//
//  LogoImageView.swift
//  WatchTrans iOS
//
//  Created by Claude on 18/1/26.
//  Loads transport operator logos from API with local fallback
//

import SwiftUI
import Kingfisher

struct LogoImageView: View {
    let logoType: LogoType
    let height: CGFloat

    private static let baseURL = APIConfiguration.logosBaseURL

    enum LogoType {
        /// Remote logo by network code, with transport type for fallback icon
        case network(code: String, transportType: TransportType)
        /// Custom asset icon only (no remote logo)
        case customAsset(name: String)

        /// Remote logo filename derived from network code
        var remoteFilename: String? {
            switch self {
            case .network(let code, _):
                return code.lowercased()
            case .customAsset:
                return nil
            }
        }

        var fileExtension: String { "png" }

        /// Fallback custom asset name matching the transport type
        var fallbackAssetName: String {
            switch self {
            case .network(_, let transportType):
                return Self.assetName(for: transportType)
            case .customAsset(let name):
                return name
            }
        }

        /// Map TransportType to ISO 7001 custom asset
        static func assetName(for type: TransportType) -> String {
            switch type {
            case .metro: return "MetroSymbol"
            case .tren: return "TrenSymbol"
            case .tram: return "TramSymbol"
            case .bus: return "BusSymbol"
            case .funicular: return "FunicularSymbol"
            }
        }
    }

    var remoteURL: URL? {
        guard let filename = logoType.remoteFilename else { return nil }
        return URL(string: "\(Self.baseURL)\(filename).\(logoType.fileExtension)")
    }

    var body: some View {
        if let url = remoteURL {
            KFImage(url)
                .placeholder {
                    SymbolView(name: logoType.fallbackAssetName, size: height * 0.6)
                        .foregroundStyle(.secondary)
                }
                .fade(duration: 0.25)
                .cacheOriginalImage()
                .resizable()
                .scaledToFit()
                .frame(height: height)
        } else {
            SymbolView(name: logoType.fallbackAssetName, size: height * 0.8)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Convenience initializers

extension LogoImageView {
    /// Create logo view from network code + transport type (for correct fallback icon)
    init(networkCode: String, type: TransportType, height: CGFloat) {
        self.height = height
        self.logoType = .network(code: networkCode, transportType: type)
    }

    /// Create logo view from network code only (fallback defaults to TrenSymbol)
    init(networkCode: String, height: CGFloat) {
        self.height = height
        self.logoType = .network(code: networkCode, transportType: .tren)
    }

    /// Create logo view from TransportType only (no remote logo, just the icon)
    init(type: TransportType, height: CGFloat) {
        self.height = height
        self.logoType = .customAsset(name: LogoType.assetName(for: type))
    }
}

#Preview {
    VStack(spacing: 20) {
        LogoImageView(networkCode: "METRO_SEVILLA", type: .metro, height: 20)
        LogoImageView(networkCode: "RENFE_C4", type: .tren, height: 20)
        LogoImageView(type: .metro, height: 20)
        LogoImageView(type: .tren, height: 20)
        LogoImageView(type: .bus, height: 20)
    }
}
