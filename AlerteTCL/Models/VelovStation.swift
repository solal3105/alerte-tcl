import Foundation
import CoreLocation

/// Une station Vélo'v (vélos en libre-service JCDecaux à Lyon).
/// Source : data.grandlyon.com — collection `jcd_jcdecaux.jcdvelov` (temps réel,
/// rafraîchie ~toutes les minutes côté Grand Lyon).
struct VelovStation: Identifiable {
    /// Numéro de station JCDecaux (ex: 2010). Stable, sert d'identifiant.
    let id: Int
    let name: String
    let address: String?
    let commune: String?
    let coordinate: CLLocationCoordinate2D

    let totalCapacity: Int
    let availableBikes: Int
    let availableStands: Int
    let availableMechanicalBikes: Int
    let availableElectricalBikes: Int

    let status: Status
    /// Station acceptant le paiement par carte bancaire en direct.
    let banking: Bool
    /// "Station bonus" — restitution +15 min (en haut d'une côte).
    let bonus: Bool

    let lastUpdate: Date?

    enum Status: String {
        case open = "OPEN"
        case closed = "CLOSED"

        var isOperational: Bool { self == .open }
    }

    // MARK: - Derived

    /// Nom nettoyé (l'API renvoie `"2010 - CONFLUENCE / DARSE"`, on enlève le préfixe numérique).
    var displayName: String {
        let parts = name.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2,
              let firstTrimmed = parts.first?.trimmingCharacters(in: .whitespaces),
              Int(firstTrimmed) != nil else {
            return name
        }
        return parts[1].trimmingCharacters(in: .whitespaces)
    }

    /// Pourcentage de remplissage (0.0 = vide, 1.0 = plein).
    var fillRatio: Double {
        guard totalCapacity > 0 else { return 0 }
        return Double(availableBikes) / Double(totalCapacity)
    }

    /// Catégorie de disponibilité — utilisée pour la couleur du marqueur sur la carte.
    var availability: Availability {
        guard status.isOperational else { return .closed }
        if availableBikes == 0 { return .empty }
        if availableStands == 0 { return .full }
        if availableBikes <= 2 || availableStands <= 2 { return .low }
        return .ok
    }

    enum Availability {
        case ok        // bien fourni des deux côtés
        case low       // peu de vélos OU peu de bornettes (≤ 2)
        case empty     // 0 vélo
        case full      // 0 bornette libre
        case closed    // station fermée

        var label: String {
            switch self {
            case .ok:     return "Disponible"
            case .low:    return "Faible"
            case .empty:  return "Aucun vélo"
            case .full:   return "Station pleine"
            case .closed: return "Fermée"
            }
        }
    }
}

// MARK: - GeoJSON Decoding

struct VelovResponse: Decodable {
    let features: [VelovFeature]
}

struct VelovFeature: Decodable {
    let geometry: VelovGeometry
    let properties: VelovProperties
}

struct VelovGeometry: Decodable {
    let coordinates: [Double] // [lng, lat]
    var coordinate: CLLocationCoordinate2D? {
        guard coordinates.count >= 2 else { return nil }
        return CLLocationCoordinate2D(latitude: coordinates[1], longitude: coordinates[0])
    }
}

struct VelovProperties: Decodable {
    let number: Int
    let name: String
    let address: String?
    let commune: String?
    let bikeStands: Int?
    let availableBikeStands: Int?
    let availableBikes: Int?
    let status: String?
    let banking: Bool?
    let bonus: Bool?
    let lastUpdate: String?
    let totalStands: TotalStands?

    enum CodingKeys: String, CodingKey {
        case number, name, address, commune, status, banking, bonus
        case bikeStands = "bike_stands"
        case availableBikeStands = "available_bike_stands"
        case availableBikes = "available_bikes"
        case lastUpdate = "last_update"
        case totalStands = "total_stands"
    }

    struct TotalStands: Decodable {
        let availabilities: Availabilities?

        struct Availabilities: Decodable {
            let mechanicalBikes: Int?
            let electricalBikes: Int?

            enum CodingKeys: String, CodingKey {
                case mechanicalBikes
                case electricalBikes
            }
        }
    }
}

extension VelovStation {
    /// Construit une `VelovStation` à partir d'une feature GeoJSON.
    /// Renvoie `nil` si les champs essentiels (id, position) manquent.
    init?(feature: VelovFeature) {
        guard let coord = feature.geometry.coordinate else { return nil }
        let p = feature.properties

        let mech = p.totalStands?.availabilities?.mechanicalBikes ?? 0
        let elec = p.totalStands?.availabilities?.electricalBikes ?? 0

        self.init(
            id: p.number,
            name: p.name,
            address: p.address,
            commune: p.commune,
            coordinate: coord,
            totalCapacity: p.bikeStands ?? 0,
            availableBikes: p.availableBikes ?? 0,
            availableStands: p.availableBikeStands ?? 0,
            availableMechanicalBikes: mech,
            availableElectricalBikes: elec,
            status: Status(rawValue: p.status ?? "OPEN") ?? .open,
            banking: p.banking ?? false,
            bonus: p.bonus ?? false,
            lastUpdate: Self.parseDate(p.lastUpdate)
        )
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func parseDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        return isoFormatter.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }
}
