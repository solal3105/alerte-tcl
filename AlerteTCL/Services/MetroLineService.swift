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
            #if DEBUG
            print("✅ Utilisation du cache pour les lignes de transport")
            #endif
            return cached
        }
        
        #if DEBUG
        print("🔄 Chargement des lignes de transport depuis l'API...")
        #endif
        
        // Charger métro/funiculaire et tramways en parallèle
        async let metroFuniLines = fetchLinesFromAPI(url: metroFuniURL, type: "métro/funiculaire")
        async let tramLines = fetchLinesFromAPI(url: tramURL, type: "tramway")
        
        do {
            let (metroFuni, tram) = try await (metroFuniLines, tramLines)
            let allLines = metroFuni + tram
            
            // Mettre en cache
            cachedTransitLines = allLines
            cacheTimestamp = Date()
            
            #if DEBUG
            print("✅ \(allLines.count) lignes de transport chargées (\(metroFuni.count) métro/funi + \(tram.count) tram)")
            #endif
            
            return allLines
            
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
        
        var request = URLRequest(url: finalURL)
        request.timeoutInterval = 30
        
        // Ajouter l'authentification Basic Auth
        if let username = Bundle.main.object(forInfoDictionaryKey: "GrandLyonUsername") as? String,
           let password = Bundle.main.object(forInfoDictionaryKey: "GrandLyonPassword") as? String {
            let credentials = "\(username):\(password)"
            if let credentialsData = credentials.data(using: .utf8) {
                let base64Credentials = credentialsData.base64EncodedString()
                request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
            }
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }
        
        #if DEBUG
        print("📡 Réponse API lignes \(type): \(httpResponse.statusCode)")
        #endif
        
        guard httpResponse.statusCode == 200 else {
            throw ServiceError.invalidResponse
        }
        
        let apiResponse = try JSONDecoder().decode(TransitLineResponse.self, from: data)
        return parseTransitLines(from: apiResponse, type: type)
    }
    
    private func parseTransitLines(from response: TransitLineResponse, type: String) -> [TransitLine] {
        let transitLines: [TransitLine] = response.features.compactMap { feature -> TransitLine? in
            guard let ligne = feature.properties.ligne,
                  let famille = feature.properties.famille_transport,
                  !feature.geometry.coordinates.isEmpty else {
                return nil
            }
            
            // Extraire toutes les coordonnées de la MultiLineString
            var allCoordinates: [[Double]] = []
            for lineString in feature.geometry.coordinates {
                allCoordinates.append(contentsOf: lineString)
            }
            
            return TransitLine(
                id: feature.id,
                name: ligne,
                coordinates: allCoordinates,
                familyTransport: famille
            )
        }
        
        #if DEBUG
        print("📊 Lignes \(type): \(transitLines.count) (\(transitLines.map { $0.name }.joined(separator: ", ")))")
        #endif
        
        return transitLines
    }
    
    func clearCache() {
        cachedTransitLines = nil
        cacheTimestamp = nil
    }
}
