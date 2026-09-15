import Foundation
import CoreLocation
import SwiftUI
import Shared

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
    
    /// Épaisseur et couleur officielle du tracé, règles partagées avec Android.
    var lineWidth: CGFloat { CGFloat(MapStyle.shared.routeWidth(line: name)) }

    var lineColor: Color { LineColorHelper.backgroundColor(for: name) }
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
    let sens: String?
    let nomDestination: String?

    enum CodingKeys: String, CodingKey {
        case ligne, nom_trace, famille_transport, sens
        case nomDestination = "nom_destination"
    }
}

// L'extension Color(hex:) vit dans Utilities/ColorHex.swift (partagée avec le widget).
