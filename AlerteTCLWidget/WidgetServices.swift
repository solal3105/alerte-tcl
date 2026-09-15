//
//  WidgetServices.swift
//  AlerteTCLWidget
//
//  Services simplifiés pour les widgets
//

import Foundation
import SwiftUI

// MARK: - Shared URLSession

/// Session unique de l'extension : la créer par requête empêchait toute réutilisation
/// de connexion et laissait des sessions non invalidées derrière chaque timeline.
private enum WidgetNetwork {
    static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        config.waitsForConnectivity = false
        config.urlCache = nil
        return URLSession(configuration: config)
    }()
}

// MARK: - Shared formatters (expensive to create — kept as static)

private enum WidgetFormatters {
    static let apiDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Paris")
        return f
    }()

    static let displayTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Paris")
        return f
    }()
}

// MARK: - Shared App Group cache for last successful passages

private enum WidgetCache {
    private static var defaults: UserDefaults? { AppGroup.defaults }

    private struct CachedPassages: Codable {
        let passages: [WidgetPassage]
        let fetchedAt: Date
    }

    private static func key(stopId: Int, line: String, direction: String) -> String {
        "widget.passages.\(stopId).\(line.uppercased()).\(direction.lowercased())"
    }

    static func store(_ passages: [WidgetPassage], stopId: Int, line: String, direction: String) {
        guard let defaults else { return }
        let payload = CachedPassages(passages: passages, fetchedAt: Date())
        if let data = try? JSONEncoder().encode(payload) {
            defaults.set(data, forKey: key(stopId: stopId, line: line, direction: direction))
        }
    }

    /// Returns cached passages when no older than `maxAge` seconds.
    /// Les délais relatifs sont décrémentés de l'âge du cache et les passages
    /// déjà écoulés écartés ; les délais absolus (péremption invérifiable) aussi.
    /// Le badge temps réel est retiré : ces données ne le sont plus.
    static func load(stopId: Int, line: String, direction: String, maxAge: TimeInterval = 15 * 60) -> [WidgetPassage]? {
        guard let defaults,
              let data = defaults.data(forKey: key(stopId: stopId, line: line, direction: direction)),
              let cached = try? JSONDecoder().decode(CachedPassages.self, from: data) else { return nil }
        let age = Date().timeIntervalSince(cached.fetchedAt)
        guard age <= maxAge else { return nil }
        let elapsedMinutes = Int(age / 60)
        let adjusted = cached.passages.compactMap { passage -> WidgetPassage? in
            guard let minutes = passage.delayMinutes else { return nil }
            let remaining = minutes - elapsedMinutes
            guard remaining >= 0 else { return nil }
            return WidgetPassage(
                delay: remaining == 0 ? "À l'approche" : "\(remaining) min",
                time: passage.time,
                isRealTime: false
            )
        }
        return adjusted.isEmpty ? nil : adjusted
    }
}

// MARK: - Passage Service for Widget

struct WidgetPassageService {
    // URL mise à jour automatiquement par deploy.sh (proxy Cloudflare — sans credentials dans l'app)
    private static let passagesEndpoint = "https://tcl-proxy.solalgendrin.workers.dev/passages"

    /// Fetches real-time passages. Falls back to last successful cached response on failure.
    static func fetchPassages(stopId: Int, line: String, direction: String) async throws -> [WidgetPassage] {
        do {
            let fresh = try await performNetworkFetch(stopId: stopId, line: line, direction: direction)
            WidgetCache.store(fresh, stopId: stopId, line: line, direction: direction)
            return fresh
        } catch {
            // Fallback cache : les délais sont ajustés de l'âge du cache et les
            // passages écoulés écartés par load(). Fenêtre de 90 min, cohérente
            // avec le filtrage appliqué au fetch — au-delà, tout serait écarté.
            if let cached = WidgetCache.load(stopId: stopId, line: line, direction: direction, maxAge: 90 * 60) {
                AppLogger.debug("⚠️ Widget: réseau KO, fallback cache (\(cached.count) passages)")
                return cached
            }
            throw error
        }
    }

    private static func performNetworkFetch(stopId: Int, line: String, direction: String) async throws -> [WidgetPassage] {
        // Le proxy Cloudflare accepte /passages?id=<stopId>
        // (avant déploiement, le script deploy.sh remplace l'URL par celle du worker)
        let urlString = "\(passagesEndpoint)?id=\(stopId)"

        guard let url = URL(string: urlString) else {
            throw WidgetError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("AlerteTCL/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        let (data, response) = try await WidgetNetwork.session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WidgetError.invalidResponse
        }

        let passagesResponse = try JSONDecoder().decode(WidgetPassagesResponse.self, from: data)

        let now = Date()
        let normalizedLine = line.uppercased().trimmingCharacters(in: .whitespaces)
        let normalizedDirection = direction.lowercased().trimmingCharacters(in: .whitespaces)
        let directionPrefix = String(normalizedDirection.prefix(8))

        let filtered = passagesResponse.values.filter { value in
            let valueLine = value.ligne.uppercased().trimmingCharacters(in: .whitespaces)
            let valueDirection = value.direction.lowercased().trimmingCharacters(in: .whitespaces)
            let matchesLine = valueLine == normalizedLine
            let matchesDirection = valueDirection.contains(directionPrefix) || normalizedDirection.contains(String(valueDirection.prefix(8)))
            guard matchesLine && matchesDirection else { return false }
            guard let passageDate = WidgetFormatters.apiDate.date(from: value.heurepassage) else { return true }
            // Exclure les passages passés et les passages à plus de 90 min (données de fin de service)
            return passageDate >= now && passageDate.timeIntervalSince(now) <= 90 * 60
        }

        let sorted = filtered.sorted { lhs, rhs in
            let d1 = WidgetFormatters.apiDate.date(from: lhs.heurepassage) ?? .distantFuture
            let d2 = WidgetFormatters.apiDate.date(from: rhs.heurepassage) ?? .distantFuture
            return d1 < d2
        }

        return sorted.prefix(6).map { value in
            let time: String
            if let passageDate = WidgetFormatters.apiDate.date(from: value.heurepassage) {
                time = WidgetFormatters.displayTime.string(from: passageDate)
            } else {
                time = "--:--"
            }
            return WidgetPassage(
                delay: value.delaipassage,
                time: time,
                // "E" = passage estimé en temps réel, "T" = horaire théorique
                isRealTime: value.type == "E"
            )
        }
    }
}

// MARK: - Widget Passages Response

struct WidgetPassagesResponse: Codable {
    let values: [WidgetPassageValue]
}

struct WidgetPassageValue: Codable {
    let id: Int
    let ligne: String
    let direction: String
    let delaipassage: String
    let heurepassage: String
    let type: String
}

// MARK: - Line Color Helper for Widget

// MARK: - Parking Service for Widget

/// Dernière occupation connue par parking, pour survivre à une coupure réseau.
private enum WidgetParkingCache {
    private static let maxAge: TimeInterval = 60 * 60

    private struct CachedParking: Codable {
        let parking: WidgetParking
        let fetchedAt: Date
    }

    private static func key(id: String) -> String { "widget.parking.\(id)" }

    static func store(_ parking: WidgetParking) {
        guard let defaults = AppGroup.defaults else { return }
        let payload = CachedParking(parking: parking, fetchedAt: Date())
        if let data = try? JSONEncoder().encode(payload) {
            defaults.set(data, forKey: key(id: parking.id))
        }
    }

    static func load(id: String) -> WidgetParking? {
        guard let defaults = AppGroup.defaults,
              let data = defaults.data(forKey: key(id: id)),
              let cached = try? JSONDecoder().decode(CachedParking.self, from: data),
              Date().timeIntervalSince(cached.fetchedAt) <= maxAge else { return nil }
        return cached.parking
    }
}

struct WidgetParkingService {
    static func fetchParking(withId parkingId: String) async -> WidgetParking? {
        do {
            let parkings = try await fetchParkings()
            let parking = parkings.first(where: { $0.id == parkingId })
            if let parking { WidgetParkingCache.store(parking) }
            return parking
        } catch {
            AppLogger.debug("❌ Widget: Erreur récupération parking: \(error)")
            // Mieux vaut une occupation récente qu'un widget vide
            return WidgetParkingCache.load(id: parkingId)
        }
    }

    private static func fetchParkings() async throws -> [WidgetParking] {
        let urlString = "https://data.grandlyon.com/geoserver/ogc/features/v1/collections/metropole-de-lyon:parkings-de-la-metropole-de-lyon-disponibilites-temps-reel-v2/items?f=application/json&sortby=gid"

        guard let url = URL(string: urlString) else {
            throw WidgetError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        let (data, _) = try await WidgetNetwork.session.data(for: request)

        let response = try JSONDecoder().decode(WidgetParkingResponse.self, from: data)
        return response.features.map { WidgetParking(from: $0) }
    }
}

// MARK: - Widget Models

struct WidgetParking: Codable {
    let id: String
    let nom: String
    // Optionnels : le GeoServer renvoie null quand le capteur est indisponible ;
    // la vue bascule alors sur « Données indisponibles » au lieu d'afficher « 0 / 0 »
    let placesDisponibles: Int?
    let capaciteTotale: Int?

    init(from feature: WidgetParkingFeature) {
        self.id = feature.properties.id
        self.nom = feature.properties.nom
        self.placesDisponibles = feature.properties.placesDisponibles
        self.capaciteTotale = feature.properties.nbPlaces
    }
}

struct WidgetParkingResponse: Codable {
    let features: [WidgetParkingFeature]
}

struct WidgetParkingFeature: Codable {
    let properties: WidgetParkingProperties
}

struct WidgetParkingProperties: Codable {
    let id: String
    let nom: String
    let placesDisponibles: Int?
    let nbPlaces: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case nom
        case placesDisponibles = "places_disponibles"
        case nbPlaces = "nb_places"
    }
}

enum WidgetError: Error {
    case invalidURL
    case invalidResponse
}
