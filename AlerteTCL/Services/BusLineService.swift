import Foundation
import CoreLocation

actor BusLineService {
    static let shared = BusLineService()
    
    private let baseURL = "https://data.grandlyon.com/geoserver/ogc/features/v1/collections/sytral:tcl_sytral.tcllignebus_2_0_0/items"
    
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
            #if DEBUG
            print("✅ Utilisation du cache pour les lignes de bus")
            #endif
            return cached
        }
        
        #if DEBUG
        print("🔄 Chargement des lignes de bus depuis l'API...")
        #endif
        
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
        
        // Ajouter l'authentification Basic Auth
        if let creds = SecretsManager.grandLyonCredentials {
            let credString = "\(creds.username):\(creds.password)"
            if let credentialsData = credString.data(using: .utf8) {
                let base64Credentials = credentialsData.base64EncodedString()
                request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
            }
        }
        
        do {
            let (data, response) = try await NetworkConfiguration.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ServiceError.invalidResponse
            }
            
            #if DEBUG
            print("📡 Réponse API lignes de bus: \(httpResponse.statusCode)")
            #endif
            
            guard httpResponse.statusCode == 200 else {
                throw ServiceError.invalidResponse
            }
            
            let apiResponse = try JSONDecoder().decode(BusLineResponse.self, from: data)
            let busLines = parseBusLines(from: apiResponse)
            
            // Mettre en cache
            cachedBusLines = busLines
            cacheTimestamp = Date()
            
            #if DEBUG
            print("✅ \(busLines.count) lignes de bus chargées et mises en cache")
            #endif
            
            return busLines
            
        } catch let error as DecodingError {
            #if DEBUG
            print("❌ Erreur de décodage: \(error)")
            #endif
            throw ServiceError.decodingError
        } catch {
            #if DEBUG
            print("❌ Erreur réseau: \(error)")
            #endif
            throw ServiceError.networkError(error)
        }
    }
    
    private func parseBusLines(from response: BusLineResponse) -> [BusLine] {
        let busLines: [BusLine] = response.features.compactMap { feature -> BusLine? in
            guard let ligne = feature.properties.ligne,
                  !feature.geometry.coordinates.isEmpty else {
                return nil
            }
            
            // Extraire toutes les coordonnées de la MultiLineString
            var allCoordinates: [[Double]] = []
            for lineString in feature.geometry.coordinates {
                allCoordinates.append(contentsOf: lineString)
            }
            
            return BusLine(
                id: feature.id,
                name: ligne,
                coordinates: allCoordinates
            )
        }
        
        #if DEBUG
        print("📊 Lignes C chargées: \(busLines.count)")
        print("📊 Exemples: \(busLines.prefix(5).map { $0.name }.joined(separator: ", "))")
        #endif
        
        return busLines
    }
    
    func clearCache() {
        cachedBusLines = nil
        cacheTimestamp = nil
    }
}
