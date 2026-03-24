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
        case network(code: String)  // Use network code directly for remote logo
        case sfSymbol(name: String) // Fallback SF Symbol

        /// Remote logo filename derived from network code
        var remoteFilename: String? {
            switch self {
            case .network(let code):
                // The API serves logos at /logos/{code}.png
                return code.lowercased()
            case .sfSymbol:
                return nil
            }
        }

        var fileExtension: String { "png" }

        /// SF Symbol fallback
        var sfSymbol: String {
            switch self {
            case .network:
                return "tram.fill"
            case .sfSymbol(let name):
                return name
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
                    Image(systemName: logoType.sfSymbol)
                        .font(.system(size: height * 0.6))
                        .foregroundStyle(.secondary)
                }
                .fade(duration: 0.25)
                .cacheOriginalImage()
                .resizable()
                .scaledToFit()
                .frame(height: height)
        } else {
            Image(systemName: logoType.sfSymbol)
                .font(.system(size: height * 0.8))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Convenience initializers

extension LogoImageView {
    /// Create logo view from network code (preferred)
    init(networkCode: String, height: CGFloat) {
        self.height = height
        self.logoType = .network(code: networkCode)
    }

    /// Create logo view from TransportType with SF Symbol fallback
    init(type: TransportType, height: CGFloat) {
        self.height = height
        let symbol: String
        switch type {
        case .metro: symbol = "tram.tunnel.fill"
        case .tren: symbol = "tram.fill"
        case .tram: symbol = "lightrail.fill"
        case .bus: symbol = "bus.fill"
        case .funicular: symbol = "cablecar"
        }
        self.logoType = .sfSymbol(name: symbol)
    }
}

#Preview {
    VStack(spacing: 20) {
        LogoImageView(networkCode: "METRO_SEVILLA", height: 20)
        LogoImageView(networkCode: "RENFE_C4", height: 20)
        LogoImageView(type: .metro, height: 20)
        LogoImageView(type: .tren, height: 20)
    }
}
