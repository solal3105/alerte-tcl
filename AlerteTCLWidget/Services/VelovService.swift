import CoreLocation
import Foundation

/// Stations Vélo'v depuis le relais `/velov` (données ouvertes du Grand Lyon, allégées).
enum VelovService {
    struct Station: Codable, Hashable, Identifiable {
        let id: Int
        let name: String
        let address: String?
        let lat: Double
        let lng: Double
        let bikes: Int
        let ebikes: Int?
        let stands: Int
        let capacity: Int?
        let open: Bool?
        /// Epoch en secondes.
        let updated: Int64?

        var isOpen: Bool { open ?? true }

        /// « Valdo / Rivet » : sans le numéro, en minuscules avec majuscules initiales (même règle que l'application).
        var displayName: String {
            let raw = name.range(of: " - ").map { String(name[$0.upperBound...]) } ?? name
            return raw.trimmingCharacters(in: .whitespaces).lowercased()
                .split(separator: " ", omittingEmptySubsequences: false)
                .map { word in
                    word.split(separator: "-", omittingEmptySubsequences: false)
                        .map { part in part.prefix(1).uppercased() + part.dropFirst() }
                        .joined(separator: "-")
                }
                .joined(separator: " ")
        }

        func snapshot(distanceMeters: Double?) -> WidgetVelovSnapshot {
            WidgetVelovSnapshot(
                id: id, name: displayName, address: address ?? "",
                bikes: bikes, ebikes: ebikes ?? 0,
                stands: stands, capacity: capacity ?? (bikes + stands), open: isOpen,
                updated: updated.map { Date(timeIntervalSince1970: TimeInterval($0)) },
                distanceMeters: distanceMeters
            )
        }
    }

    private struct Response: Decodable {
        let stations: [Station]
    }

    struct Result {
        let stations: [Station]
        let fetchedAt: Date
        let stale: Bool
    }

    private static let cacheKey = "velov.stations"
    /// Le relais rafraîchit toutes les minutes ; entre deux widgets, une même liste suffit cinq minutes.
    private static let freshAge: TimeInterval = 5 * 60
    private static let staleMaxAge: TimeInterval = 60 * 60

    /// Toutes les stations : un chargement récent, sinon le réseau, sinon un chargement plus ancien.
    static func stations(now: Date = Date()) async -> Result? {
        if let fresh = WidgetStore.cached([Station].self, key: cacheKey, maxAge: freshAge) {
            return Result(stations: fresh.value, fetchedAt: fresh.savedAt, stale: false)
        }
        do {
            let response = try await WidgetNetwork.json(Response.self, from: "\(ProxyEndpoint.baseURL)/velov")
            WidgetStore.cache(response.stations, key: cacheKey)
            return Result(stations: response.stations, fetchedAt: now, stale: false)
        } catch {
            AppLogger.debug("Stations Vélo'v injoignables : \(error.localizedDescription)", category: .widget)
            guard let cached = WidgetStore.cached([Station].self, key: cacheKey, maxAge: staleMaxAge) else { return nil }
            return Result(stations: cached.value, fetchedAt: cached.savedAt, stale: true)
        }
    }

    static func station(id: Int) async -> (station: Station, fetchedAt: Date, stale: Bool)? {
        guard let result = await stations(), let station = result.stations.first(where: { $0.id == id }) else { return nil }
        return (station, result.fetchedAt, result.stale)
    }

    /// La station ouverte la plus proche, avec sa distance.
    static func nearest(to location: CLLocation) async -> (station: Station, distance: Double, fetchedAt: Date, stale: Bool)? {
        guard let result = await stations() else { return nil }
        let candidates = result.stations.filter(\.isOpen).map { station in
            (station, location.distance(from: CLLocation(latitude: station.lat, longitude: station.lng)))
        }
        guard let best = candidates.min(by: { $0.1 < $1.1 }) else { return nil }
        return (best.0, best.1, result.fetchedAt, result.stale)
    }

    /// Stations dont le nom ou l'adresse contient le texte cherché, sans tenir compte des accents.
    static func search(_ query: String) async -> [Station] {
        guard let result = await stations() else { return [] }
        let needle = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        guard !needle.trimmingCharacters(in: .whitespaces).isEmpty else { return sorted(result.stations) }
        return sorted(result.stations.filter { station in
            "\(station.displayName) \(station.address ?? "")".folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).contains(needle)
        })
    }

    static func sorted(_ stations: [Station]) -> [Station] {
        stations.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }
}
