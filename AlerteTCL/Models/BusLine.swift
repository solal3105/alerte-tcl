import Foundation
import CoreLocation
import SwiftUI

// MARK: - Bus Line Model

struct BusLine: Identifiable, Codable {
    let id: String
    let name: String
    let coordinates: [[Double]]
    
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
        4.0 // Toutes les lignes chargées sont des lignes C
    }
    
    var lineColor: Color {
        Color.gray.opacity(0.6) // Toutes les lignes chargées sont des lignes C
    }
}

// MARK: - API Response Models

struct BusLineResponse: Codable {
    let features: [BusLineFeature]
}

struct BusLineFeature: Codable {
    let id: String
    let geometry: BusLineGeometry
    let properties: BusLineProperties
}

struct BusLineGeometry: Codable {
    let type: String
    let coordinates: [[[Double]]]
}

struct BusLineProperties: Codable {
    let ligne: String?
    let nom_trace: String?
}
