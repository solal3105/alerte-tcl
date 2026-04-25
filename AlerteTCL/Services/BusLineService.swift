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
    
    enum ServiceError: Error {
        case invalidURL
        case invalidResponse
        case decodingError
        case networkError(Error)
    }
    
    func fetchBusLines() async throws -> [BusLine] {
        // Vérifier le cache
        if let cached = cachedBusLines,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheValidityDuration {
            AppLogger.debug("✅ Utilisation du cache pour les lignes de bus")
            return cached
        }
        
        AppLogger.debug("🔄 Chargement des lignes de bus depuis l'API...")
        
        guard var components = URLComponents(string: baseURL) else {
            throw ServiceError.invalidURL
        }
        
        // Paramètres de requête - filtrer uniquement les lignes C côté serveur
        components.queryItems = [
            URLQueryItem(name: "limit", value: "500"),
            URLQueryItem(name: "f", value: "json"),
            URLQueryItem(name: "filter", value: "ligne LIKE 'C%'")
        ]
        
        guard let url = components.url else {
            throw ServiceError.invalidURL
        }
        
        var request = NetworkConfiguration.request(url: url, timeout: NetworkConfiguration.sharedTimeout)
        request.setValue("AlerteTCL/1.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await NetworkConfiguration.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ServiceError.invalidResponse
            }
            
            AppLogger.debug("📡 Réponse API lignes de bus: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                throw ServiceError.invalidResponse
            }
            
            let apiResponse = try JSONDecoder().decode(BusLineResponse.self, from: data)
            let busLines = parseBusLines(from: apiResponse)
            
            // Mettre en cache
            cachedBusLines = busLines
            cacheTimestamp = Date()
            
            AppLogger.debug("✅ \(busLines.count) lignes de bus chargées et mises en cache")
            
            return busLines
            
        } catch let error as DecodingError {
            AppLogger.debug("❌ Erreur de décodage: \(error)")
            throw ServiceError.decodingError
        } catch {
            AppLogger.debug("❌ Erreur réseau: \(error)")
            throw ServiceError.networkError(error)
        }
    }
    
    private func parseBusLines(from response: BusLineResponse) -> [BusLine] {
        var busLines: [BusLine] = []
        
        for feature in response.features {
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
