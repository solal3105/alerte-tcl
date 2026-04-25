import Foundation
import MapKit

actor TravauxService {
    static let shared = TravauxService()
    
    // Nouveau endpoint OGC Features pour "Travaux engagés sur la Métropole de Lyon"
    private let baseURL = "https://data.grandlyon.com/geoserver/ogc/features/v1/collections/metropole-de-lyon:lyv_lyvia.lyvchantier/items"
    
    // Cache simple avec expiration
    private var cache: (travaux: [Travaux], timestamp: Date)?
    private let cacheValidity: TimeInterval = 300 // 5 minutes
    
    private init() {}
    
    func fetchTravaux(forceRefresh: Bool = false) async throws -> [Travaux] {
        // Vérifier le cache
        if !forceRefresh, let cached = cache {
            let age = Date().timeIntervalSince(cached.timestamp)
            if age < cacheValidity {
                AppLogger.debug("✨ TravauxService: Cache hit (âge: \(Int(age))s)")
                return cached.travaux
            }
        }
        
        // Utiliser le nouveau endpoint OGC Features API
        let urlString = "\(baseURL)?f=application/json&limit=500"
        
        guard let url = URL(string: urlString) else {
            AppLogger.debug("❌ TravauxService: URL invalide")
            throw TravauxServiceError.invalidURL
        }
        
        AppLogger.debug("🌐 TravauxService: Chargement...")
        
        var request = NetworkConfiguration.request(url: url, timeout: NetworkConfiguration.sharedTimeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("AlerteTCL/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        
        let (data, response) = try await NetworkConfiguration.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TravauxServiceError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            AppLogger.debug("❌ TravauxService: HTTP \(httpResponse.statusCode)")
            throw TravauxServiceError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let travauxResponse = try decoder.decode(TravauxResponse.self, from: data)
        
        let travaux = travauxResponse.features.map { Travaux(from: $0) }
        
        // Filtrer les chantiers actifs (en cours ou prévus)
        let activeTravaux = travaux.filter { $0.isActive }
        
        // Mettre en cache
        cache = (travaux: activeTravaux, timestamp: Date())
        
        AppLogger.debug("✅ TravauxService: \(activeTravaux.count) chantiers actifs")
        
        return activeTravaux
    }
    
}

enum TravauxServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL invalide"
        case .invalidResponse:
            return "Réponse invalide du serveur"
        case .httpError(let code):
            return "Erreur HTTP: \(code)"
        }
    }
}
