import Foundation
import CoreLocation

// MARK: - Decoding types (GeoJSON SYTRAL P+R)

private struct ParcRelaisStaticResponse: Codable {
    let features: [ParcRelaisStaticFeature]
}
private struct ParcRelaisStaticFeature: Codable {
    let geometry: ParcRelaisGeometry
    let properties: ParcRelaisStaticProperties
}
private struct ParcRelaisRealtimeResponse: Codable {
    let features: [ParcRelaisRealtimeFeature]
}
private struct ParcRelaisRealtimeFeature: Codable {
    let properties: ParcRelaisRealtimeProperties
}
private struct ParcRelaisGeometry: Codable {
    let coordinates: [[Double]]   // MultiPoint → premier point
    var coordinate: CLLocationCoordinate2D? {
        guard let first = coordinates.first, first.count >= 2 else { return nil }
        return CLLocationCoordinate2D(latitude: first[1], longitude: first[0])
    }
}
private struct ParcRelaisStaticProperties: Codable {
    let id: String
    let nom: String
    let capacite: Int?
    let placeHandi: Int?
    let horaires: String?
    let pSurv: Bool?
    enum CodingKeys: String, CodingKey {
        case id, nom, capacite, horaires
        case placeHandi = "place_handi"
        case pSurv = "p_surv"
    }
}
private struct ParcRelaisRealtimeProperties: Codable {
    let id: String
    let nbTotPlaceDispo: Int?
    enum CodingKeys: String, CodingKey {
        case id
        case nbTotPlaceDispo = "nb_tot_place_dispo"
    }
}

// MARK: - Service

actor ParcRelaisService {
    static let shared = ParcRelaisService()
    private init() {}

    private let staticURL   = NetworkConfiguration.proxyBaseURL + "/parc-relais?f=application/json&limit=100&sortby=gid"
    private let realtimeURL = NetworkConfiguration.proxyBaseURL + "/parc-relais-tr?f=application/json&limit=100&sortby=gid"

    // Cache statique — 24h
    private var cachedStatic: [Parking]?
    private var cacheTimestamp: Date?
    private let cacheValidity: TimeInterval = 86_400

    // Cache temps réel — 60s
    private var lastRealtimeFetch: Date?
    private let realtimeValidity: TimeInterval = 60

    // MARK: - Public API

    /// Retourne les P+R fusionnés avec les données temps réel disponibles.
    func fetchParcRelais(forceRefresh: Bool = false) async throws -> [Parking] {
        let now = Date()

        // 1. Données statiques (cache 24h)
        let staticList: [Parking]
        if !forceRefresh,
           let cached = cachedStatic,
           let ts = cacheTimestamp,
           now.timeIntervalSince(ts) < cacheValidity {
            staticList = cached
        } else {
            staticList = try await fetchStatic()
            cachedStatic = staticList
            cacheTimestamp = now
        }

        // 2. Données temps réel (cache 60s)
        let shouldRefreshRT = forceRefresh
            || lastRealtimeFetch == nil
            || now.timeIntervalSince(lastRealtimeFetch!) >= realtimeValidity

        guard shouldRefreshRT else { return staticList }

        let rtMap = (try? await fetchRealtimeMap()) ?? [:]
        lastRealtimeFetch = now

        // 3. Fusionner — reconstruire Parking avec dispo si disponible
        return staticList.map { pr in
            // Extraire l'id brut (on a préfixé "parc-relais-" dans l'init)
            let rawId = String(pr.id.dropFirst("parc-relais-".count))
            guard let dispo = rtMap[rawId] else { return pr }
            return Parking(
                parcRelaisId: rawId,
                nom: pr.nom,
                coordinate: pr.coordinate,
                capacite: pr.capaciteTotale,
                placesHandicap: pr.nbPmr ?? 0,
                horaires: pr.horaires,
                surveille: pr.surveille ?? false,
                placesDisponibles: dispo
            )
        }
    }

    // MARK: - Private helpers

    private func fetchStatic() async throws -> [Parking] {
        guard let url = URL(string: staticURL) else { throw ParcRelaisError.invalidURL }
        let (data, _) = try await NetworkConfiguration.shared.data(for: NetworkConfiguration.request(url: url, timeout: NetworkConfiguration.sharedTimeout))
        let resp = try JSONDecoder().decode(ParcRelaisStaticResponse.self, from: data)
        return resp.features.compactMap { feature -> Parking? in
            guard let coord = feature.geometry.coordinate else { return nil }
            let p = feature.properties
            return Parking(
                parcRelaisId: p.id,
                nom: p.nom,
                coordinate: coord,
                capacite: p.capacite ?? 0,
                placesHandicap: p.placeHandi ?? 0,
                horaires: p.horaires,
                surveille: p.pSurv ?? false,
                placesDisponibles: nil
            )
        }
    }

    private func fetchRealtimeMap() async throws -> [String: Int] {
        guard let url = URL(string: realtimeURL) else { throw ParcRelaisError.invalidURL }
        let (data, _) = try await NetworkConfiguration.shared.data(for: NetworkConfiguration.request(url: url, timeout: NetworkConfiguration.sharedTimeout))
        let resp = try JSONDecoder().decode(ParcRelaisRealtimeResponse.self, from: data)
        var map: [String: Int] = [:]
        for feature in resp.features {
            if let dispo = feature.properties.nbTotPlaceDispo {
                map[feature.properties.id] = dispo
            }
        }
        return map
    }
}

enum ParcRelaisError: LocalizedError {
    case invalidURL
    var errorDescription: String? { "URL invalide" }
}
