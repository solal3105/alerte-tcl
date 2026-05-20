//
//  WidgetServices.swift
//  AlerteTCLWidget
//
//  Services simplifiés pour les widgets
//

import Foundation
import SwiftUI

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
    private static let appGroup = "group.com.solal.alertetcl"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

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
    static func load(stopId: Int, line: String, direction: String, maxAge: TimeInterval = 15 * 60) -> [WidgetPassage]? {
        guard let defaults,
              let data = defaults.data(forKey: key(stopId: stopId, line: line, direction: direction)),
              let cached = try? JSONDecoder().decode(CachedPassages.self, from: data) else { return nil }
        guard Date().timeIntervalSince(cached.fetchedAt) <= maxAge else { return nil }
        return cached.passages
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
            // Fallback cache sans limite d'âge stricte : après plusieurs jours d'inactivité
            // iOS peut appeler timeline() très rarement ; mieux vaut afficher des données
            // potentiellement périmées que montrer une erreur vide.
            if let cached = WidgetCache.load(stopId: stopId, line: line, direction: direction, maxAge: 4 * 3600) {
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

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        config.waitsForConnectivity = false
        config.urlCache = nil
        let session = URLSession(configuration: config)
        let (data, response) = try await session.data(for: request)

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
                isRealTime: value.type == "R"
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

struct WidgetLineColorHelper {
    static func backgroundColor(for ligne: String) -> Color {
        let upper = ligne.uppercased()

        if upper == "MA" || upper == "A" {
            return Color(red: 238/255, green: 56/255, blue: 152/255)
        } else if upper == "MB" || upper == "B" {
            return Color(red: 0/255, green: 125/255, blue: 197/255)
        } else if upper == "MC" || upper == "C" {
            return Color(red: 249/255, green: 157/255, blue: 29/255)
        } else if upper == "MD" || upper == "D" {
            return Color(red: 0/255, green: 172/255, blue: 77/255)
        } else if upper == "RX" || upper.contains("RHONEXPRESS") {
            return Color(red: 201/255, green: 43/255, blue: 33/255)
        } else if upper.hasPrefix("T") && upper.count <= 3 {
            return Color(red: 103/255, green: 56/255, blue: 119/255)
        } else if upper.hasPrefix("TB") {
            return Color(red: 1.0, green: 0.8, blue: 0.0)
        } else if upper.hasPrefix("F") && upper.count <= 3 {
            return .orange
        } else if upper.hasPrefix("C") && upper.count <= 4 {
            return Color(.systemGray)
        } else if upper.hasPrefix("JD") {
            return Color(red: 42/255, green: 36/255, blue: 117/255)
        }
        return .blue
    }

    static func textColor(for ligne: String) -> Color {
        let upper = ligne.uppercased()

        if upper.hasPrefix("JD") {
            return Color(red: 235/255, green: 202/255, blue: 47/255)
        } else if upper.hasPrefix("C") && upper.count <= 4 {
            return .white
        } else if upper.hasPrefix("T") && upper.count <= 3 {
            return .white
        } else if !upper.hasPrefix("M") &&
                  !upper.hasPrefix("F") &&
                  !upper.hasPrefix("TB") &&
                  upper != "A" && upper != "B" && upper != "C" && upper != "D" &&
                  !upper.contains("RHONEXPRESS") && upper != "RX" {
            return .red
        }
        return .white
    }
}

// MARK: - Parking Service for Widget

struct WidgetParkingService {
    static func fetchParking(withId parkingId: String) async -> WidgetParking? {
        do {
            let parkings = try await fetchParkings()
            return parkings.first(where: { $0.id == parkingId })
        } catch {
            AppLogger.debug("❌ Widget: Erreur récupération parking: \(error)")
            return nil
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

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        config.waitsForConnectivity = false
        config.urlCache = nil
        let session = URLSession(configuration: config)
        let (data, _) = try await session.data(for: request)

        let response = try JSONDecoder().decode(WidgetParkingResponse.self, from: data)
        return response.features.map { WidgetParking(from: $0) }
    }
}

// MARK: - Widget Models

struct WidgetParking {
    let id: String
    let nom: String
    let placesDisponibles: Int
    let capaciteTotale: Int

    init(from feature: WidgetParkingFeature) {
        self.id = feature.properties.id
        self.nom = feature.properties.nom
        self.placesDisponibles = feature.properties.placesDisponibles ?? 0
        self.capaciteTotale = feature.properties.nbPlaces ?? 0
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
