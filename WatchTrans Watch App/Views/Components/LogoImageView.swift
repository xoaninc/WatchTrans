//
//  LogoImageView.swift
//  WatchTrans Watch App
//
//  Created by Claude on 18/1/26.
//  Loads transport operator logos from API with local fallback
//

import SwiftUI

struct LogoImageView: View {
    let logoType: LogoType
    let height: CGFloat

    @State private var loadedImageData: Data?
    @State private var loadState: LoadState = .idle

    private static let baseURL = "https://redcercanias.com/static/logos/"

    enum LoadState {
        case idle, loading, loaded, failed
    }

    enum LogoType {
        case cercanias
        case rodalies
        case metro(nucleo: String)
        case metroLigero
        case tram(nucleo: String)
        case fgc
        case euskotren
        case sfm

        /// Remote logo filename (without extension)
        var remoteFilename: String? {
            switch self {
            case .cercanias:
                return "cercanias"
            case .rodalies:
                return "rodalies"
            case .metro(let nucleo):
                switch nucleo.lowercased() {
                case "madrid":
                    return "metro_madrid"
                case "sevilla":
                    return "metro_sevilla"
                case "bilbao", "vizcaya":
                    return "metro_bilbao"
                case "valencia":
                    return "metro_valencia"
                case "málaga", "malaga":
                    return "metro_malaga"
                case "granada":
                    return "metro_granada"
                case "barcelona":
                    return "tmb_metro"
                case "mallorca", "palma":
                    return "sfm_mallorca"
                // Tenerife no tiene metro, tiene tranvía
                default:
                    return nil
                }
            case .metroLigero:
                return "metro_ligero_madrid"
            case .tram(let nucleo):
                switch nucleo.lowercased() {
                case "zaragoza":
                    return "tranvia_zaragoza"
                case "murcia", "murcia/alicante":
                    return "tranvia_murcia"
                case "alicante":
                    return "tram_alicante"
                case "barcelona":
                    return "tram_bcn"
                case "sevilla":
                    return "tranvia_sevilla"
                case "tenerife":
                    return "tranvia_tenerife"
                default:
                    return nil
                }
            case .fgc:
                return "fgc"
            case .euskotren:
                return "euskotren"
            case .sfm:
                return "sfm_mallorca"
            }
        }

        /// File extension (all .png - webp not well supported on watchOS)
        var fileExtension: String {
            return "png"
        }

        /// Local asset name - only return if we have the CORRECT logo for this city
        /// Returns nil if we should use SF Symbol instead (to avoid showing wrong city's logo)
        var localAssetName: String? {
            switch self {
            case .cercanias:
                return "CercaniasLogo"  // RENFE es igual en toda España
            case .rodalies:
                return "RodaliesLogo"   // Rodalies de Catalunya
            case .metroLigero:
                return "MetroLigeroLogo"  // Metro Ligero Madrid
            case .metro(let nucleo):
                // Solo devolver logo si tenemos el correcto para esa ciudad
                switch nucleo.lowercased() {
                case "madrid":
                    return "MetroLogo"  // El MetroLogo es el rombo de Madrid
                case "sevilla":
                    return "MetroSevillaLogo"
                // TODO: Añadir cuando tengamos los logos:
                // case "barcelona": return "MetroBarcelonaLogo"
                // case "valencia": return "MetroValenciaLogo"
                // case "bilbao": return "MetroBilbaoLogo"
                default:
                    return nil  // Usar SF Symbol en vez de logo incorrecto
                }
            case .tram:
                // No tenemos logos específicos de tram por ciudad
                return nil  // Usar SF Symbol
            case .fgc:
                return nil  // Usar SF Symbol - no tenemos logo FGC
            case .euskotren:
                return nil  // Usar SF Symbol - no tenemos logo Euskotren
            case .sfm:
                return nil  // Usar SF Symbol - no tenemos logo SFM Mallorca
            }
        }

        /// SF Symbol for ultimate fallback
        var sfSymbol: String {
            switch self {
            case .cercanias, .rodalies, .fgc, .euskotren, .sfm:
                return "tram.fill"
            case .metro, .metroLigero:
                return "tram.tunnel.fill"
            case .tram:
                return "lightrail.fill"
            }
        }
    }

    var remoteURL: URL? {
        guard let filename = logoType.remoteFilename else { return nil }
        return URL(string: "\(Self.baseURL)\(filename).\(logoType.fileExtension)")
    }

    var body: some View {
        Group {
            switch loadState {
            case .idle, .loading:
                // Show SF Symbol while loading
                Image(systemName: logoType.sfSymbol)
                    .font(.system(size: height * 0.6))
                    .foregroundStyle(.secondary)
            case .loaded:
                if let data = loadedImageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: height)
                } else {
                    localImage
                }
            case .failed:
                localImage
            }
        }
        .task(id: logoType.remoteFilename) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let filename = logoType.remoteFilename else {
            loadState = .failed
            return
        }

        let cacheKey = "\(filename).\(logoType.fileExtension)"

        // Check cache first
        if let cached = await ImageCacheService.shared.getImageData(for: cacheKey) {
            loadedImageData = cached
            loadState = .loaded
            return
        }

        // Load from network
        guard let url = remoteURL else {
            loadState = .failed
            return
        }

        loadState = .loading

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            // Verify it's valid image data
            if UIImage(data: data) != nil {
                // Save to cache for offline use
                await ImageCacheService.shared.saveImageData(data, for: cacheKey)
                loadedImageData = data
                loadState = .loaded
            } else {
                loadState = .failed
            }
        } catch {
            loadState = .failed
        }
    }

    @ViewBuilder
    private var localImage: some View {
        if let assetName = logoType.localAssetName,
           let uiImage = UIImage(named: assetName) {
            // We have the correct logo for this city
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(height: height)
        } else {
            // Use SF Symbol - better than showing wrong city's logo
            Image(systemName: logoType.sfSymbol)
                .font(.system(size: height * 0.8))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Convenience initializers

extension LogoImageView {
    /// Create logo view from agency_id
    init(agencyId: String, nucleo: String, height: CGFloat) {
        self.height = height

        // Determine logo type from agency_id
        if agencyId == "METRO_LIGERO" {
            self.logoType = .metroLigero
        } else if agencyId == "TMB_METRO" {
            self.logoType = .metro(nucleo: "Barcelona")
        } else if agencyId == "FGC" {
            self.logoType = .fgc
        } else if agencyId.hasPrefix("EUSKOTREN") {
            self.logoType = .euskotren
        } else if agencyId.hasPrefix("SFM_MALLORCA") {
            self.logoType = .sfm
        } else if agencyId.hasPrefix("METRO_") {
            self.logoType = .metro(nucleo: nucleo)
        } else if agencyId.hasPrefix("TRANVIA_") || agencyId.hasPrefix("TRAM_") {
            self.logoType = .tram(nucleo: nucleo)
        } else if nucleo.lowercased() == "rodalies de catalunya" {
            self.logoType = .rodalies
        } else {
            self.logoType = .cercanias
        }
    }

    /// Create logo view from TransportType
    init(type: TransportType, nucleo: String, height: CGFloat) {
        self.height = height

        switch type {
        case .metro:
            self.logoType = .metro(nucleo: nucleo)
        case .metroLigero:
            self.logoType = .metroLigero
        case .tram:
            self.logoType = .tram(nucleo: nucleo)
        case .fgc:
            self.logoType = .fgc
        case .cercanias:
            if nucleo.lowercased() == "rodalies de catalunya" {
                self.logoType = .rodalies
            } else {
                self.logoType = .cercanias
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        LogoImageView(logoType: .cercanias, height: 20)
        LogoImageView(logoType: .metro(nucleo: "Madrid"), height: 20)
        LogoImageView(logoType: .metro(nucleo: "Sevilla"), height: 20)
        LogoImageView(logoType: .tram(nucleo: "Zaragoza"), height: 20)
    }
}
