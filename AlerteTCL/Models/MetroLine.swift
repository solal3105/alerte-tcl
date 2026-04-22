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
        switch name.uppercased() {
        // Métro
        case "A":
            return Color(hex: "EE3898") // Rose/Fuchsia
        case "B":
            return Color(hex: "007DC5") // Bleu
        case "C":
            return Color(hex: "F99D1D") // Orange
        case "D":
            return Color(hex: "00AC4D") // Vert
        // Funiculaires
        case "F1", "F2":
            return Color(hex: "8BC752") // Vert clair
        // Tramways (toutes les lignes T)
        case "T1", "T2", "T3", "T4", "T5", "T6", "T7":
            return Color(hex: "8C368C") // Violet/Mauve
        default:
            return Color.gray
        }
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
    let sens: String?
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
