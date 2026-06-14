import Foundation
import CoreLocation

actor BusLineService {
    static let shared = BusLineService()
    
    private let baseURL = NetworkConfiguration.proxyBaseURL + "/bus-lines"
    
    // Cache en mémoire
    private var cachedBusLines: [BusLine]?
    private var cacheTimestamp: Date?
    private let cacheValidityDuration: TimeInterval = 86400 // 24 heures

    private init() {}
    
    func fetchBusLines() async throws -> [BusLine] {
        // Vérifier le cache
        if let cached = cachedBusLines,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheValidityDuration {
            AppLogger.debug("✅ Utilisation du cache pour les lignes de bus")
            return cached
        }
        
        AppLogger.debug("🔄 Chargement des lignes de bus depuis l'API...")
        
        do {
            let allFeatures = try await fetchAllPages()
            let busLines = parseBusLines(from: allFeatures)
            cachedBusLines = busLines
            cacheTimestamp = Date()
            AppLogger.debug("✅ \(busLines.count) lignes de bus chargées et mises en cache")
            return busLines
        } catch let error as DecodingError {
            AppLogger.debug("❌ Erreur de décodage: \(error)")
            throw ServiceError.decodingError(error)
        } catch {
            AppLogger.debug("❌ Erreur réseau: \(error)")
            throw ServiceError.networkError(error)
        }
    }

    private func fetchAllPages() async throws -> [BusLineFeature] {
        let pageSize = 1000
        var allFeatures: [BusLineFeature] = []
        var startIndex = 0
        var total: Int? = nil

        repeat {
            guard var components = URLComponents(string: baseURL) else {
                throw ServiceError.invalidURL
            }
            components.queryItems = [
                URLQueryItem(name: "limit", value: "\(pageSize)"),
                URLQueryItem(name: "startIndex", value: "\(startIndex)"),
                URLQueryItem(name: "f", value: "json")
            ]
            guard let url = components.url else { throw ServiceError.invalidURL }

            var request = NetworkConfiguration.request(url: url, timeout: NetworkConfiguration.sharedTimeout)
            request.setValue("AlerteTCL/1.0", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await NetworkConfiguration.session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw ServiceError.invalidResponse
            }

            let page = try JSONDecoder().decode(BusLineResponse.self, from: data)
            allFeatures.append(contentsOf: page.features)
            if total == nil { total = page.numberMatched }
            startIndex += page.features.count

            AppLogger.debug("📄 Lignes de bus: \(startIndex)/\(total ?? 0) features chargées")
        } while startIndex < (total ?? 0) && !allFeatures.isEmpty

        return allFeatures
    }
    
    private func parseBusLines(from features: [BusLineFeature]) -> [BusLine] {
        var busLines: [BusLine] = []
        
        for feature in features {
            guard let ligne = feature.properties.ligne,
                  !feature.geometry.coordinates.isEmpty else {
                continue
            }
            
            // Créer un BusLine par segment (évite les lignes parasites entre segments)
            for (idx, lineString) in feature.geometry.coordinates.enumerated() {
                guard !lineString.isEmpty else { continue }
                busLines.append(BusLine(
                    id: "\(feature.id)_\(idx)",
                    name: ligne,
                    coordinates: lineString
                ))
            }
        }
        
        AppLogger.debug("📊 Lignes C chargées: \(busLines.count) segments")
        AppLogger.debug("📊 Exemples: \(Set(busLines.map { $0.name }).sorted().prefix(5).joined(separator: ", "))")
        
        return busLines
    }
}
