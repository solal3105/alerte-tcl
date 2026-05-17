import Foundation
import CoreLocation
import SwiftUI

/// Un véhicule Dott en free-floating (trottinette électrique à Lyon).
/// Source : flux GBFS public Dott (`free_bike_status.json`).
struct DottVehicle: Identifiable, Clusterable {
    /// Identifiant Dott (UUID), stable et utilisé pour le deep-link.
    let id: String

    let coordinate: CLLocationCoordinate2D

    /// Batterie 0.0 - 1.0.
    let batteryPercent: Double
    /// Autonomie restante en mètres.
    let rangeMeters: Int
    /// Type de véhicule (à ce jour Dott Lyon = scooter uniquement).
    let kind: Kind

    let isReserved: Bool
    let isDisabled: Bool

    /// Deep-link iOS pour ouvrir l'app Dott directement sur ce véhicule.
    let rentalURL: URL?

    /// Heure GBFS de dernière mise à jour de ce véhicule.
    let lastReported: Date?

    enum Kind: String {
        case scooter = "dott_scooter"
        case ebike   = "dott_ebike"
        case unknown

        var label: String {
            switch self {
            case .scooter: return "Trottinette"
            case .ebike:   return "Vélo électrique"
            case .unknown: return "Véhicule"
            }
        }

        var icon: String {
            switch self {
            case .scooter: return "scooter"
            case .ebike:   return "bicycle"
            case .unknown: return "questionmark.circle"
            }
        }
    }

    // MARK: - Derived

    /// Catégorie de batterie - utilisée pour la couleur du marqueur.
    var batteryLevel: BatteryLevel {
        if batteryPercent < 0.2 { return .low }
        if batteryPercent < 0.5 { return .medium }
        return .high
    }

    enum BatteryLevel {
        case low      // < 20 %
        case medium   // 20 - 50 %
        case high     // >= 50 %

        var color: Color {
            switch self {
            case .low:    return .red
            case .medium: return .orange
            case .high:   return .green
            }
        }

        var label: String {
            switch self {
            case .low:    return "Batterie faible"
            case .medium: return "Batterie correcte"
            case .high:   return "Batterie pleine"
            }
        }
    }

    var batteryPercentInt: Int { Int((batteryPercent * 100).rounded()) }

    /// Autonomie en km, arrondie au dixième.
    var rangeKm: Double { Double(rangeMeters) / 1000 }

    // MARK: - Clusterable

    var clusterColor: Color { batteryLevel.color }
    var clusterIcon: String { kind.icon }
}

// MARK: - GBFS Decoding

struct DottFeedResponse: Decodable {
    let data: DottFeedData
    let lastUpdated: Int?
    let ttl: Int?

    enum CodingKeys: String, CodingKey {
        case data
        case lastUpdated = "last_updated"
        case ttl
    }
}

struct DottFeedData: Decodable {
    let bikes: [DottFeedVehicle]
}

struct DottFeedVehicle: Decodable {
    let bikeId: String
    let lat: Double
    let lon: Double
    let currentFuelPercent: Double?
    let currentRangeMeters: Double?
    let vehicleTypeId: String?
    let isReserved: Bool?
    let isDisabled: Bool?
    let lastReported: Int?
    let rentalUris: RentalUris?

    enum CodingKeys: String, CodingKey {
        case bikeId = "bike_id"
        case lat, lon
        case currentFuelPercent = "current_fuel_percent"
        case currentRangeMeters = "current_range_meters"
        case vehicleTypeId = "vehicle_type_id"
        case isReserved = "is_reserved"
        case isDisabled = "is_disabled"
        case lastReported = "last_reported"
        case rentalUris = "rental_uris"
    }

    struct RentalUris: Decodable {
        let ios: String?
        let android: String?
    }
}

extension DottVehicle {
    /// Construit un `DottVehicle` à partir d'une entrée GBFS.
    init?(feed: DottFeedVehicle) {
        guard !feed.bikeId.isEmpty else { return nil }
        self.init(
            id: feed.bikeId,
            coordinate: CLLocationCoordinate2D(latitude: feed.lat, longitude: feed.lon),
            batteryPercent: feed.currentFuelPercent ?? 0,
            rangeMeters: Int(feed.currentRangeMeters ?? 0),
            kind: Kind(rawValue: feed.vehicleTypeId ?? "") ?? .unknown,
            isReserved: feed.isReserved ?? false,
            isDisabled: feed.isDisabled ?? false,
            rentalURL: feed.rentalUris?.ios.flatMap(URL.init(string:)),
            lastReported: feed.lastReported.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        )
    }
}
