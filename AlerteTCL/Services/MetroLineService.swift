import Foundation
import CoreLocation

actor TransitLineService {
    static let shared = TransitLineService()
    
    private let metroFuniURL = "https://data.grandlyon.com/geoserver/ogc/features/v1/collections/sytral:tcl_sytral.tcllignemf_2_0_0/items"
    private let tramURL = "https://data.grandlyon.com/geoserver/ogc/features/v1/collections/sytral:tcl_sytral.tcllignetram_2_0_0/items"
    
    // Cache en mémoire
    private var cachedTransitLines: [TransitLine]?
    private var cacheTimestamp: Date?
    private let cacheValidityDuration: TimeInterval = 86400 // 24 heures
    
    private init() {}
    
    enum ServiceError: Error {
        case invalidURL
        case invalidResponse
        case decodingError
        case networkError(Error)
    }
    
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
            
            AppLogger.debug("✅ \(allLines.count) lignes de transport chargées (\(metroFuni.count) métro/funi + \(tram.count) tram)")
            
            return allLines
            
        } catch let error as DecodingError {
            AppLogger.debug("❌ Erreur de décodage: \(error)")
            throw ServiceError.decodingError
        } catch {
            AppLogger.debug("❌ Erreur réseau: \(error)")
            throw ServiceError.networkError(error)
        }
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
        
        request.setBasicAuth(SecretsManager.grandLyonCredentials)
        
        let (data, response) = try await NetworkConfiguration.shared.data(for: request)
        
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
    
    func clearCache() {
        cachedTransitLines = nil
        cacheTimestamp = nil
    }
}
