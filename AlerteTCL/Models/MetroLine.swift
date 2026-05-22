import Foundation
import CoreLocation
import SwiftUI

// MARK: - Transit Line Model (Metro, Funiculaire, Tramway)

struct TransitLine: Identifiable, Codable {
    let id: String
    let name: String
    let coordinates: [[Double]]
    let familyTransport: String
    
    var clLocationCoordinates: [CLLocationCoordinate2D] {
        let converted = coordinates.compactMap(CLLocationCoordinate2D.fromGeoJSON)
        
        #if DEBUG
        if converted.isEmpty && !coordinates.isEmpty {
            AppLogger.debug("⚠️ Ligne \(name): \(coordinates.count) coords mais 0 converties!")
        }
        #endif
        
        return converted
    }
    
    var lineWidth: CGFloat {
        3.0 // Lignes de métro/funiculaire
    }
    
    var lineColor: Color {
        LineColorHelper.backgroundColor(for: name)
    }
}

// MARK: - API Response Models

struct TransitLineResponse: Codable {
    let features: [TransitLineFeature]
}

struct TransitLineFeature: Codable {
    let id: String
    let geometry: TransitLineGeometry
    let properties: TransitLineProperties
}

struct TransitLineGeometry: Codable {
    let type: String
    let coordinates: [[[Double]]]
}

struct TransitLineProperties: Codable {
    let ligne: String?
    let nom_trace: String?
    let famille_transport: String?
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
