import Foundation

/// Gerätegrößen und Rasterregeln für das Pad. Mac-Vorschau, iOS-App und Webseite rechnen damit gleich.
enum PadDevice: String, CaseIterable, Identifiable {
    case phonePortrait, phoneLandscape, tabletLandscape, tabletPortrait

    var id: String { rawValue }

    var title: String {
        switch self {
        case .phonePortrait: return "iPhone hoch"
        case .phoneLandscape: return "iPhone quer"
        case .tabletLandscape: return "iPad quer"
        case .tabletPortrait: return "iPad hoch"
        }
    }

    var isTablet: Bool {
        self == .tabletLandscape || self == .tabletPortrait
    }

    /// Bildschirmgröße in Punkten.
    var width: Double {
        switch self {
        case .phonePortrait: return 390
        case .phoneLandscape: return 844
        case .tabletLandscape: return 1180
        case .tabletPortrait: return 820
        }
    }

    var height: Double {
        switch self {
        case .phonePortrait: return 844
        case .phoneLandscape: return 390
        case .tabletLandscape: return 820
        case .tabletPortrait: return 1180
        }
    }

    /// Seitenrand des Rasters (im Querformat am iPhone inklusive Sicherheitsabstand der Aussparung).
    var sidePadding: Double {
        switch self {
        case .phonePortrait: return 14
        case .phoneLandscape: return 48
        case .tabletLandscape, .tabletPortrait: return 28
        }
    }

    var gap: Double {
        isTablet ? 12 : 8
    }

    /// So viele Spalten passen mit der Mindestgröße nebeneinander (mindestens eine).
    func columns(minTile: Double) -> Int {
        let usable = width - 2 * sidePadding
        let count = Int(((usable + gap) / (minTile + gap)).rounded(.down))
        return max(1, count)
    }

    /// Kantenlänge eines Buttons bei der gegebenen Spaltenzahl.
    func tileSize(columns: Int) -> Double {
        let usable = width - 2 * sidePadding - Double(columns - 1) * gap
        return usable / Double(max(1, columns))
    }
}
