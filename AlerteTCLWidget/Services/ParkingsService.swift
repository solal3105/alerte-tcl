import Foundation

/// Un parking proposé au réglage du widget : identifiant du jeu de données, nom, parc relais ou non.
struct WidgetParkingCatalogItem: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let isParcRelais: Bool
}

/// Parkings voiture (GeoServer, disponibilité temps réel) et parcs relais TCL (relais, statique et
/// temps réel) : même identifiants que l'application, pour que le lien ouvre la bonne fiche.
enum ParkingsService {
    private static let parcRelaisPrefix = "parc-relais-"
    private static let carURL = "\(WidgetNetwork.geoServerBase)/metropole-de-lyon:parkings-de-la-metropole-de-lyon-disponibilites-temps-reel-v2/items?f=application/json&limit=500&sortby=gid"
    private static let parcRelaisStaticURL = "\(ProxyEndpoint.baseURL)/parc-relais?f=application/json&limit=100&sortby=gid"
    private static let parcRelaisRealtimeURL = "\(ProxyEndpoint.baseURL)/parc-relais-tr?f=application/json&limit=100&sortby=gid"

    private struct CarResponse: Decodable {
        let features: [CarFeature]
    }

    private struct CarFeature: Decodable {
        let properties: CarProperties
    }

    private struct CarProperties: Decodable {
        let gid: Int
        let id: String?
        let nom: String
        let nbPlaces: Int?
        let placesDisponibles: Int?
        let etat: String?

        enum CodingKeys: String, CodingKey {
            case gid, id, nom, etat
            case nbPlaces = "nb_places"
            case placesDisponibles = "places_disponibles"
        }

        var parkingId: String { id ?? "\(gid)" }
    }

    private struct ParcRelaisStaticResponse: Decodable {
        let features: [ParcRelaisStaticFeature]
    }

    private struct ParcRelaisStaticFeature: Decodable {
        let properties: ParcRelaisStaticProperties
    }

    private struct ParcRelaisStaticProperties: Decodable {
        let id: String
        let nom: String
        let capacite: Int?
    }

    private struct ParcRelaisRealtimeResponse: Decodable {
        let features: [ParcRelaisRealtimeFeature]
    }

    private struct ParcRelaisRealtimeFeature: Decodable {
        let properties: ParcRelaisRealtimeProperties
    }

    private struct ParcRelaisRealtimeProperties: Decodable {
        let id: String
        let nbTotPlaceDispo: Int?

        enum CodingKeys: String, CodingKey {
            case id
            case nbTotPlaceDispo = "nb_tot_place_dispo"
        }
    }

    // MARK: - Catalogue (réglage du widget)

    /// Tous les parcs relais puis tous les parkings voiture, par ordre alphabétique ; gardé un jour.
    static func catalog() async -> [WidgetParkingCatalogItem] {
        if let cached = WidgetStore.cached([WidgetParkingCatalogItem].self, key: "parkings.catalog", maxAge: 86_400) {
            return cached.value
        }
        var items: [WidgetParkingCatalogItem] = []
        if let parcRelais = try? await WidgetNetwork.json(ParcRelaisStaticResponse.self, from: parcRelaisStaticURL) {
            items += parcRelais.features
                .map { WidgetParkingCatalogItem(id: parcRelaisPrefix + $0.properties.id, name: $0.properties.nom, isParcRelais: true) }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
        if let cars = try? await WidgetNetwork.json(CarResponse.self, from: carURL) {
            items += cars.features
                .map { WidgetParkingCatalogItem(id: $0.properties.parkingId, name: $0.properties.nom, isParcRelais: false) }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
        if !items.isEmpty { WidgetStore.cache(items, key: "parkings.catalog") }
        return items
    }

    // MARK: - Disponibilité

    struct Result {
        let parking: WidgetParkingSnapshot
        let fetchedAt: Date
        let stale: Bool
    }

    /// La disponibilité d'un parking, ou sa dernière valeur connue (moins d'une heure) faute de réseau.
    static func snapshot(id: String, now: Date = Date()) async -> Result? {
        let cacheKey = "parking.\(id)"
        do {
            let parking = id.hasPrefix(parcRelaisPrefix) ? try await parcRelais(id: id) : try await carParking(id: id)
            guard let parking else { return nil }
            WidgetStore.cache(parking, key: cacheKey)
            return Result(parking: parking, fetchedAt: now, stale: false)
        } catch {
            AppLogger.debug("Parking \(id) injoignable : \(error.localizedDescription)", category: .widget)
            guard let cached = WidgetStore.cached(WidgetParkingSnapshot.self, key: cacheKey, maxAge: 3600) else { return nil }
            return Result(parking: cached.value, fetchedAt: cached.savedAt, stale: true)
        }
    }

    /// Dernière valeur connue, quel que soit son âge : sert à nommer un parking sans réseau.
    static func lastKnown(id: String) -> WidgetParkingSnapshot? {
        WidgetStore.cached(WidgetParkingSnapshot.self, key: "parking.\(id)", maxAge: .infinity)?.value
    }

    private static func carParking(id: String) async throws -> WidgetParkingSnapshot? {
        let response = try await WidgetNetwork.json(CarResponse.self, from: carURL)
        guard let properties = response.features.map(\.properties).first(where: { $0.parkingId == id }) else { return nil }
        let state = (properties.etat ?? "").lowercased()
        return WidgetParkingSnapshot(
            id: id, name: properties.nom,
            available: properties.placesDisponibles, capacity: properties.nbPlaces,
            isParcRelais: false, open: state != "ferme"
        )
    }

    private static func parcRelais(id: String) async throws -> WidgetParkingSnapshot? {
        let rawId = String(id.dropFirst(parcRelaisPrefix.count))
        let statics = try await WidgetNetwork.json(ParcRelaisStaticResponse.self, from: parcRelaisStaticURL)
        guard let properties = statics.features.map(\.properties).first(where: { $0.id == rawId }) else { return nil }
        // Sans flux temps réel pour ce parc, la capacité seule est affichée.
        let realtime = try? await WidgetNetwork.json(ParcRelaisRealtimeResponse.self, from: parcRelaisRealtimeURL)
        let available = realtime?.features.map(\.properties).first(where: { $0.id == rawId })?.nbTotPlaceDispo
        return WidgetParkingSnapshot(
            id: id, name: properties.nom,
            available: available, capacity: properties.capacite,
            isParcRelais: true, open: true
        )
    }
}
