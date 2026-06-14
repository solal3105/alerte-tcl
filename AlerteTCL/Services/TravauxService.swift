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
        if !forceRefresh, let cached = cache {
            let age = Date().timeIntervalSince(cached.timestamp)
            if age < cacheValidity {
                AppLogger.debug("✨ TravauxService: Cache hit (âge: \(Int(age))s)")
                return cached.travaux
            }
        }
        
        AppLogger.debug("🌐 TravauxService: Chargement...")
        
        // limit=2000 couvre le dataset complet (1116 records actuels) en une seule requête.
        // GeoServer Grand Lyon supporte jusqu'à ~10 000 sans pagination.
        guard let url = URL(string: "\(baseURL)?f=application/json&limit=2000") else {
            throw ServiceError.invalidURL
        }
        
        var request = NetworkConfiguration.request(url: url, timeout: NetworkConfiguration.sharedTimeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("AlerteTCL/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        
        let (data, response) = try await NetworkConfiguration.session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw ServiceError.invalidResponse }
        guard httpResponse.statusCode == 200 else {
            AppLogger.debug("❌ TravauxService: HTTP \(httpResponse.statusCode)")
            throw ServiceError.httpError(httpResponse.statusCode)
        }
        
        let travauxResponse = try JSONDecoder().decode(TravauxResponse.self, from: data)
        let activeTravaux = travauxResponse.features.map { Travaux(from: $0) }.filter { $0.isActive }
        cache = (travaux: activeTravaux, timestamp: Date())
        AppLogger.debug("✅ TravauxService: \(activeTravaux.count) chantiers actifs (\(travauxResponse.features.count) features totales)")
        
        return activeTravaux
    }
    
}

