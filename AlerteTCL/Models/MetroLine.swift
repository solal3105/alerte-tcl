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

// L'extension Color(hex:) vit dans Utilities/ColorHex.swift (partagée avec le widget).
