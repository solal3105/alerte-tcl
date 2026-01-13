import Foundation
import CoreLocation
import SwiftUI

// MARK: - Transit Stop Model

struct TransitStop: Identifiable, Hashable {
    let id: Int
    let nom: String
    let commune: String
    let adresse: String?
    let coordinate: CLLocationCoordinate2D
    let desserte: String // Lines serving this stop (e.g. "C20:A,C20E:A,JD975:R")
    let pmr: Bool
    var passages: [Passage] = []
    
    var lines: [String] {
        // Parse desserte to extract line names
        desserte.split(separator: ",").compactMap { part in
            let linePart = part.split(separator: ":")
            return linePart.first.map { String($0) }
        }.unique()
    }
    
    var nextPassage: Passage? {
        passages.first
    }
    
    var nextPassageText: String {
        guard let next = nextPassage else { return "" }
        return next.delaipassage
    }
    
    var hasPassages: Bool {
        !passages.isEmpty
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: TransitStop, rhs: TransitStop) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Passage Model

struct Passage: Identifiable, Hashable, Codable {
    var id: String { "\(stopId)-\(ligne)-\(heurepassage)" }
    
    let stopId: Int
    let ligne: String
    let direction: String
    let delaipassage: String
    let heurepassage: String
    let type: String // T = Théorique, R = Temps réel
    
    var isRealTime: Bool {
        type == "R"
    }
    
    var lineColor: Color {
        TransportMode.detectFromLine(ligne).color
    }
    
    /// Délai formaté court (ex: "2m" au lieu de "2 minutes")
    var shortDelay: String {
        let delay = delaipassage.lowercased()
        // Remplacer "minute(s)" par "m"
        if delay.contains("minute") {
            return delay
                .replacingOccurrences(of: " minutes", with: "m")
                .replacingOccurrences(of: " minute", with: "m")
                .replacingOccurrences(of: "minutes", with: "m")
                .replacingOccurrences(of: "minute", with: "m")
        }
        return delaipassage
    }
    
    var formattedTime: String {
        // Parse heurepassage to get just the time
        let parts = heurepassage.split(separator: " ")
        if parts.count >= 2 {
            let timeParts = parts[1].split(separator: ":")
            if timeParts.count >= 2 {
                return "\(timeParts[0]):\(timeParts[1])"
            }
        }
        return heurepassage
    }
    
    enum CodingKeys: String, CodingKey {
        case stopId = "id"
        case ligne
        case direction
        case delaipassage
        case heurepassage
        case type
    }
}

// MARK: - API Response Models

struct TransitStopResponse: Codable {
    let type: String
    let features: [TransitStopFeature]
    let numberMatched: Int?
}

struct TransitStopFeature: Codable {
    let id: String
    let geometry: TransitStopGeometry
    let properties: TransitStopProperties
}

struct TransitStopGeometry: Codable {
    let type: String
    let coordinates: [Double]
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: coordinates[1], longitude: coordinates[0])
    }
}

struct TransitStopProperties: Codable {
    let id: Int
    let nom: String
    let desserte: String?
    let pmr: Bool?
    let adresse: String?
    let commune: String?
    let insee: String?
    let zone: String?
    
    enum CodingKeys: String, CodingKey {
        case id, nom, desserte, pmr, adresse, commune, insee, zone
    }
}

struct PassagesResponse: Codable {
    let fields: [String]
    let values: [PassageValue]
    let nb_results: Int?
}

struct PassageValue: Codable {
    let id: Int
    let ligne: String
    let direction: String
    let delaipassage: String
    let heurepassage: String
    let type: String
    let idtarretdestination: Int?
    let coursetheorique: String?
    let gid: Int?
    
    func toPassage() -> Passage {
        Passage(
            stopId: id,
            ligne: ligne,
            direction: direction,
            delaipassage: delaipassage,
            heurepassage: heurepassage,
            type: type
        )
    }
}

// MARK: - Extensions

extension Array where Element: Hashable {
    func unique() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

extension TransportMode {
    static func detectFromLine(_ ligne: String) -> TransportMode {
        let upper = ligne.uppercased()
        
        if upper.hasPrefix("M") && upper.count <= 3 {
            return .metro
        } else if upper.hasPrefix("T") && upper.count <= 3 {
            return .tramway
        } else if upper.hasPrefix("F") && upper.count <= 3 {
            return .funiculaire
        } else if upper.hasPrefix("C") && upper.count <= 3 {
            return .busC
        } else if upper == "RHONEXPRESS" {
            return .tramway
        }
        return .bus
    }
}

// MARK: - Line Color Helper

struct LineColorHelper {
    /// Couleur de fond pour une ligne
    static func backgroundColor(for ligne: String) -> Color {
        let upper = ligne.uppercased()
        
        // Metro - couleurs spécifiques par ligne
        if upper == "MA" || upper == "A" {
            return Color(red: 0.95, green: 0.26, blue: 0.21) // Rouge
        }
        else if upper == "MB" || upper == "B" {
            return Color(red: 0.0, green: 0.45, blue: 0.81) // Bleu
        }
        else if upper == "MC" || upper == "C" {
            return Color(red: 0.96, green: 0.65, blue: 0.14) // Orange/Jaune
        }
        else if upper == "MD" || upper == "D" {
            return Color(red: 0.0, green: 0.65, blue: 0.42) // Vert
        }
        // Rhônexpress - violet (comme tram)
        else if upper == "RX" || upper.contains("RHONEXPRESS") {
            return .purple
        }
        // Tramway - violet
        else if upper.hasPrefix("T") && upper.count <= 3 {
            return .purple
        }
        // Trolleybus TB - jaune
        else if upper.hasPrefix("TB") {
            return Color(red: 1.0, green: 0.8, blue: 0.0) // Jaune
        }
        // Funiculaire - orange
        else if upper.hasPrefix("F") && upper.count <= 3 {
            return .orange
        }
        // Bus C - gris
        else if upper.hasPrefix("C") && upper.count <= 4 {
            return Color(.systemGray)
        }
        // Bus régulier - blanc (fond clair)
        return Color(.systemBackground)
    }
    
    /// Couleur du texte pour une ligne
    static func textColor(for ligne: String) -> Color {
        let upper = ligne.uppercased()
        
        // Bus régulier (pas M, T, F, C, TB, RX) - texte sombre sur fond blanc
        if !upper.hasPrefix("M") && 
           !upper.hasPrefix("T") && 
           !upper.hasPrefix("F") && 
           !upper.hasPrefix("C") && 
           !upper.hasPrefix("TB") &&
           upper != "A" && upper != "B" && upper != "C" && upper != "D" &&
           !upper.contains("RHONEXPRESS") && upper != "RX" {
            return .primary
        }
        // Autres - texte blanc sur fond coloré
        return .white
    }
    
    /// Style de bordure nécessaire (pour les fonds blancs)
    static func needsBorder(for ligne: String) -> Bool {
        let upper = ligne.uppercased()
        // Bordure uniquement pour les bus réguliers (fond blanc)
        return !upper.hasPrefix("M") && 
               !upper.hasPrefix("T") && 
               !upper.hasPrefix("F") && 
               !upper.hasPrefix("C") && 
               !upper.hasPrefix("TB") &&
               upper != "A" && upper != "B" && upper != "D" &&
               !upper.contains("RHONEXPRESS") && upper != "RX"
    }
}

// MARK: - Clusterable Conformance (for viewport filtering)

extension TransitStop: Clusterable {
    // coordinate is already defined in the struct
    
    var clusterColor: Color {
        if let firstPassage = nextPassage {
            return TransportMode.detectFromLine(firstPassage.ligne).color
        }
        return .gray
    }
    
    var clusterIcon: String {
        "bus.fill"
    }
}

