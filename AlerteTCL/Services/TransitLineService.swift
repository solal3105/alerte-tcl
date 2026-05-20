import Foundation
import CoreLocation

actor TransitLineService {
    static let shared = TransitLineService()
    
    private let metroFuniURL = NetworkConfiguration.proxyBaseURL + "/metro-funi-lines"
    private let tramURL = NetworkConfiguration.proxyBaseURL + "/tram-lines"
    
    // Cache en mémoire
    private var cachedTransitLines: [TransitLine]?
    private var cacheTimestamp: Date?
    private let cacheValidityDuration: TimeInterval = 86400 // 24 heures
    
    private init() {}
    
    func fetchTransitLines() async throws -> [TransitLine] {
        // Vérifier le cache
        if let cached = cachedTransitLines,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheValidityDuration {
            AppLogger.debug("✅ Utilisation du cache pour les lignes de transport")
            return cached
        }

        AppLogger.debug("🔄 Chargement des lignes de transport depuis l'API...")

        // Charger métro/funiculaire et tramways en parallèle
        async let metroFuniLines = fetchLinesFromAPI(url: metroFuniURL, type: "métro/funiculaire")
        async let tramLines = fetchLinesFromAPI(url: tramURL, type: "tramway")

        do {
            let (metroFuni, tram) = try await (metroFuniLines, tramLines)
            let allLines = metroFuni + tram

            // Mettre en cache
            cachedTransitLines = allLines
            cacheTimestamp = Date()

            AppLogger.debug("✅ \(allLines.count) lignes de transport chargées depuis l'API (\(metroFuni.count) métro/funi + \(tram.count) tram)")
            return allLines

        } catch {
            AppLogger.debug("⚠️ API GeoServer indisponible (\(error.localizedDescription)), fallback sur le bundle...")
            return try loadBundledTransitLines()
        }
    }

    /// Charge les tracés depuis le JSON bundlé dans l'app (fallback hors-ligne)
    private func loadBundledTransitLines() throws -> [TransitLine] {
        guard let url = Bundle.main.url(forResource: "tcl_transit_lines", withExtension: "json") else {
            AppLogger.debug("❌ tcl_transit_lines.json introuvable dans le bundle")
            throw ServiceError.invalidResponse
        }
        let data = try Data(contentsOf: url)
        let lines = try JSONDecoder().decode([TransitLine].self, from: data)
        cachedTransitLines = lines
        cacheTimestamp = Date()
        AppLogger.debug("✅ \(lines.count) segments chargés depuis le bundle (fallback)")
        return lines
    }
    
    private func fetchLinesFromAPI(url: String, type: String) async throws -> [TransitLine] {
        guard var components = URLComponents(string: url) else {
            throw ServiceError.invalidURL
        }
        
        components.queryItems = [
            URLQueryItem(name: "limit", value: "30"),
            URLQueryItem(name: "f", value: "json")
        ]
        
        guard let finalURL = components.url else {
            throw ServiceError.invalidURL
        }
        
        var request = NetworkConfiguration.request(url: finalURL, timeout: NetworkConfiguration.sharedTimeout)
        request.setValue("AlerteTCL/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await NetworkConfiguration.session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }
        
        AppLogger.debug("📡 Réponse API lignes \(type): \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            throw ServiceError.invalidResponse
        }
        
        let apiResponse = try JSONDecoder().decode(TransitLineResponse.self, from: data)
        return parseTransitLines(from: apiResponse, type: type)
    }
    
    private func parseTransitLines(from response: TransitLineResponse, type: String) -> [TransitLine] {
        var transitLines: [TransitLine] = []
        
        for feature in response.features {
            guard let ligne = feature.properties.ligne,
                  let famille = feature.properties.famille_transport,
                  !feature.geometry.coordinates.isEmpty else {
                continue
            }
            
            // Créer un TransitLine par segment (évite les lignes parasites entre segments)
            for (idx, lineString) in feature.geometry.coordinates.enumerated() {
                guard !lineString.isEmpty else { continue }
                transitLines.append(TransitLine(
                    id: "\(feature.id)_\(idx)",
                    name: ligne,
                    coordinates: lineString,
                    familyTransport: famille
                ))
            }
        }
        
        AppLogger.debug("📊 Lignes \(type): \(transitLines.count) segments (\(Set(transitLines.map { $0.name }).sorted().joined(separator: ", ")))")
        
        return transitLines
    }
}
