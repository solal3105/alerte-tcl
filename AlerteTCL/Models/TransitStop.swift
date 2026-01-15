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
    var isLoadingPassages: Bool = false
    var passagesLoaded: Bool = false
    
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
        
        // Metro - couleurs officielles TCL
        if upper == "MA" || upper == "A" {
            return Color(red: 238/255, green: 56/255, blue: 152/255) // Rose/fuchsia rgb(238, 56, 152)
        }
        else if upper == "MB" || upper == "B" {
            return Color(red: 0/255, green: 125/255, blue: 197/255) // Bleu rgb(0, 125, 197)
        }
        else if upper == "MC" || upper == "C" {
            return Color(red: 249/255, green: 157/255, blue: 29/255) // Orange rgb(249, 157, 29)
        }
        else if upper == "MD" || upper == "D" {
            return Color(red: 0/255, green: 172/255, blue: 77/255) // Vert rgb(0, 172, 77)
        }
        // Rhônexpress - fond C92B21
        else if upper == "RX" || upper.contains("RHONEXPRESS") {
            return Color(red: 201/255, green: 43/255, blue: 33/255) // C92B21
        }
        // Tramway - fond 673877
        else if upper.hasPrefix("T") && upper.count <= 3 {
            return Color(red: 103/255, green: 56/255, blue: 119/255) // 673877
        }
        // Trolleybus TB - jaune
        else if upper.hasPrefix("TB") {
            return Color(red: 1.0, green: 0.8, blue: 0.0) // Jaune
        }
        // Funiculaire - orange
        else if upper.hasPrefix("F") && upper.count <= 3 {
            return .orange
        }
        // Bus C - gris (inchangé)
        else if upper.hasPrefix("C") && upper.count <= 4 {
            return Color(.systemGray)
        }
        // Bus JD - fond 2A2475
        else if upper.hasPrefix("JD") {
            return Color(red: 42/255, green: 36/255, blue: 117/255) // 2A2475
        }
        // Bus régulier (non-C, non-JD) - fond blanc
        return .white
    }
    
    /// Couleur du texte pour une ligne
    static func textColor(for ligne: String) -> Color {
        let upper = ligne.uppercased()
        
        // Bus JD - texte EBCA2F sur fond 2A2475
        if upper.hasPrefix("JD") {
            return Color(red: 235/255, green: 202/255, blue: 47/255) // EBCA2F
        }
        // Bus C - texte blanc sur fond gris
        else if upper.hasPrefix("C") && upper.count <= 4 {
            return .white
        }
        // Trams - texte blanc sur fond 673877
        else if upper.hasPrefix("T") && upper.count <= 3 {
            return .white
        }
        // Bus classiques - couleurs spécifiques
        else if !upper.hasPrefix("M") && 
                !upper.hasPrefix("F") &&
                !upper.hasPrefix("TB") &&
                upper != "A" && upper != "B" && upper != "C" && upper != "D" &&
                !upper.contains("RHONEXPRESS") && upper != "RX" {
            // Bus qui commencent par N - texte DC7921
            if upper.hasPrefix("N") {
                return Color(red: 220/255, green: 121/255, blue: 33/255) // DC7921
            }
            // Bus qui finissent par E - texte 5E3A18
            else if upper.hasSuffix("E") {
                return Color(red: 94/255, green: 58/255, blue: 24/255) // 5E3A18
            }
            // Autres bus classiques - texte rouge
            return .red
        }
        // Métro - texte blanc sur fond de couleur
        return .white
    }
    
    /// Style de bordure nécessaire (pour les fonds blancs)
    static func needsBorder(for ligne: String) -> Bool {
        let upper = ligne.uppercased()
        // Bordure uniquement pour les fonds blancs (bus classiques)
        return !upper.hasPrefix("M") && 
               !upper.hasPrefix("F") &&
               !upper.hasPrefix("C") &&
               !upper.hasPrefix("T") &&
               !upper.hasPrefix("TB") &&
               !upper.hasPrefix("JD") &&
               upper != "A" && upper != "B" && upper != "C" && upper != "D" &&
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
