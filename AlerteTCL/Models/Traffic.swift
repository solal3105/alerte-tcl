import Foundation
import CoreLocation
import SwiftUI

// MARK: - Traffic Event

struct TrafficEvent: Identifiable, Codable, Hashable {
    let id: String
    let eventType: TrafficEventType
    let severity: TrafficSeverity
    let title: String
    let description: String
    let latitude: Double
    let longitude: Double
    let startDate: Date?
    let endDate: Date?
    let roadName: String?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var icon: String {
        eventType.icon
    }
    
    var color: Color {
        severity.color
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: TrafficEvent, rhs: TrafficEvent) -> Bool {
        lhs.id == rhs.id
    }
}

enum TrafficEventType: String, Codable, CaseIterable {
    case accident = "accident"
    case travaux = "travaux"
    case obstacle = "obstacle"
    case manifestation = "manifestation"
    case fermeture = "fermeture"
    case embouteillage = "embouteillage"
    case autre = "autre"
    
    var icon: String {
        switch self {
        case .accident: return "car.side.rear.and.collision.and.car.side.front"
        case .travaux: return "hammer.fill"
        case .obstacle: return "exclamationmark.triangle.fill"
        case .manifestation: return "person.3.fill"
        case .fermeture: return "xmark.circle.fill"
        case .embouteillage: return "car.2.fill"
        case .autre: return "info.circle.fill"
        }
    }
    
    var displayName: String {
        switch self {
        case .accident: return "Accident"
        case .travaux: return "Travaux"
        case .obstacle: return "Obstacle"
        case .manifestation: return "Manifestation"
        case .fermeture: return "Fermeture"
        case .embouteillage: return "Embouteillage"
        case .autre: return "Autre"
        }
    }
}

enum TrafficSeverity: String, Codable, CaseIterable {
    case faible = "faible"
    case moyen = "moyen"
    case eleve = "eleve"
    case critique = "critique"
    
    var color: Color {
        switch self {
        case .faible: return .yellow
        case .moyen: return .orange
        case .eleve: return .red
        case .critique: return .purple
        }
    }
    
    var displayName: String {
        switch self {
        case .faible: return "Faible"
        case .moyen: return "Moyen"
        case .eleve: return "Élevé"
        case .critique: return "Critique"
        }
    }
}

// MARK: - Traffic Segment (État du trafic)

struct TrafficSegment: Identifiable, Codable {
    let id: String
    let roadName: String
    let coordinates: [[Double]]
    let currentSpeed: Double?
    let freeFlowSpeed: Double?
    let fluidity: TrafficFluidity
    let travelTime: Double?
    let length: Double?
    
    var clLocationCoordinates: [CLLocationCoordinate2D] {
        let coords = coordinates.map { coord in
            CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
        }
        
        // Simplifier la polyligne si elle a trop de points (optimisation)
        if coords.count > 20 {
            return simplifyPolyline(coords, tolerance: 0.0001)
        }
        
        return coords
    }
    
    private func simplifyPolyline(_ points: [CLLocationCoordinate2D], tolerance: Double) -> [CLLocationCoordinate2D] {
        guard points.count > 2 else { return points }
        
        // Algorithme de Douglas-Peucker simplifié
        // Garder 1 point sur 3 pour les polylignes complexes
        var simplified: [CLLocationCoordinate2D] = [points.first!]
        
        for i in stride(from: 3, to: points.count - 1, by: 3) {
            simplified.append(points[i])
        }
        
        simplified.append(points.last!)
        return simplified
    }
    
    var color: Color {
        fluidity.color
    }
    
    var speedRatio: Double {
        guard let current = currentSpeed, let freeFlow = freeFlowSpeed, freeFlow > 0 else {
            return 1.0
        }
        return current / freeFlow
    }
}

enum TrafficFluidity: String, Codable, CaseIterable {
    case fluide = "fluide"
    case dense = "dense"
    case sature = "sature"
    case bloque = "bloque"
    case inconnu = "inconnu"
    
    var color: Color {
        switch self {
        case .fluide: return .green
        case .dense: return .orange
        case .sature: return .red
        case .bloque: return Color(red: 0.3, green: 0, blue: 0)
        case .inconnu: return .gray
        }
    }
    
    var displayName: String {
        switch self {
        case .fluide: return "Fluide"
        case .dense: return "Dense"
        case .sature: return "Saturé"
        case .bloque: return "Bloqué"
        case .inconnu: return "Inconnu"
        }
    }
    
    static func from(speedRatio: Double) -> TrafficFluidity {
        switch speedRatio {
        case 0.75...1.0: return .fluide
        case 0.5..<0.75: return .dense
        case 0.25..<0.5: return .sature
        case 0..<0.25: return .bloque
        default: return .inconnu
        }
    }
}

// MARK: - API Response Models

struct TrafficEventsResponse: Codable {
    let type: String?
    let features: [TrafficEventFeature]
    let numberMatched: Int?
    let numberReturned: Int?
}

struct TrafficEventFeature: Codable {
    let type: String?
    let id: String?
    let geometry: TrafficGeometry?
    let properties: TrafficEventProperties
}

struct TrafficGeometry: Codable {
    let type: String
    let coordinates: TrafficCoordinates
}

enum TrafficCoordinates: Codable {
    case point([Double])
    case lineString([[Double]])
    case multiLineString([[[Double]]])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let point = try? container.decode([Double].self) {
            self = .point(point)
            return
        }
        
        if let lineString = try? container.decode([[Double]].self) {
            self = .lineString(lineString)
            return
        }
        
        if let multiLineString = try? container.decode([[[Double]]].self) {
            self = .multiLineString(multiLineString)
            return
        }
        
        throw DecodingError.typeMismatch(TrafficCoordinates.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown coordinate type"))
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .point(let coords):
            try container.encode(coords)
        case .lineString(let coords):
            try container.encode(coords)
        case .multiLineString(let coords):
            try container.encode(coords)
        }
    }
    
    var firstPoint: [Double]? {
        switch self {
        case .point(let coords):
            return coords
        case .lineString(let coords):
            return coords.first
        case .multiLineString(let coords):
            return coords.first?.first
        }
    }
}

struct TrafficEventProperties: Codable {
    let id: String?
    let gid: Int?
    let type: String?
    let publiccomment: String?
    let starttime: String?
    let endtime: String?
    let status: String?
    let networkmanagementtype: String?
    let publiceventtype: String?
    let townname: String?
    let linkname: String?
    let direction: String?
    let lastUpdate: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case gid
        case type
        case publiccomment
        case starttime
        case endtime
        case status
        case networkmanagementtype
        case publiceventtype
        case townname
        case linkname
        case direction
        case lastUpdate = "last_update"
    }
}

// MARK: - Traffic State Response

struct TrafficStateResponse: Codable {
    let type: String?
    let features: [TrafficStateFeature]
    let numberMatched: Int?
    let numberReturned: Int?
}

struct TrafficStateFeature: Codable {
    let type: String?
    let id: String?
    let geometry: TrafficGeometry?
    let properties: TrafficStateProperties
}

struct TrafficStateProperties: Codable {
    let id: String?
    let gid: Int?
    let twgid: Int?
    let code: String?
    let libelle: String?
    let zoom: Int?
    let sens: String?
    let etat: String?
    let vitesse: String?
    let longueur: Double?
    let fournisseur: String?
    let lastUpdate: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case gid
        case twgid
        case code
        case libelle
        case zoom
        case sens
        case etat
        case vitesse
        case longueur
        case fournisseur
        case lastUpdate = "last_update"
    }
}
