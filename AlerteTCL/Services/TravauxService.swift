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
                print("✨ TravauxService: Cache hit (âge: \(Int(age))s)")
                return cached.travaux
            }
        }
        
        // Utiliser le nouveau endpoint OGC Features API
        let urlString = "\(baseURL)?f=application/json&limit=500"
        
        guard let url = URL(string: urlString) else {
            print("❌ TravauxService: URL invalide")
            throw TravauxServiceError.invalidURL
        }
        
        print("🌐 TravauxService: Chargement...")
        
        var request = NetworkConfiguration.request(url: url, timeout: NetworkConfiguration.sharedTimeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("AlerteTCL/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        
        let (data, response) = try await NetworkConfiguration.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TravauxServiceError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            print("❌ TravauxService: HTTP \(httpResponse.statusCode)")
            throw TravauxServiceError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let travauxResponse = try decoder.decode(TravauxResponse.self, from: data)
        
        let travaux = travauxResponse.features.map { Travaux(from: $0) }
        
        // Filtrer les chantiers actifs (en cours ou prévus)
        let activeTravaux = travaux.filter { $0.isActive }
        
        // Mettre en cache
        cache = (travaux: activeTravaux, timestamp: Date())
        
        print("✅ TravauxService: \(activeTravaux.count) chantiers actifs")
        
        return activeTravaux
    }
    
    /// Charge les travaux dans une région spécifique (optimisé avec BBox)
    func fetchTravauxInRegion(_ region: MKCoordinateRegion) async throws -> [Travaux] {
        let bbox = BBoxHelper.bboxString(for: region, buffer: 1.5)
        let urlString = "\(baseURL)?f=application/json&limit=200&bbox=\(bbox)"
        
        guard let url = URL(string: urlString) else {
            throw TravauxServiceError.invalidURL
        }
        
        var request = NetworkConfiguration.request(url: url, timeout: NetworkConfiguration.sharedTimeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("AlerteTCL/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        
        let (data, response) = try await NetworkConfiguration.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw TravauxServiceError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let travauxResponse = try decoder.decode(TravauxResponse.self, from: data)
        
        let travaux = travauxResponse.features.map { Travaux(from: $0) }
        let activeTravaux = travaux.filter { $0.isActive }
        
        print("🚧 TravauxService: \(activeTravaux.count) chantiers dans la région")
        
        return activeTravaux
    }
    
    func fetchTravauxByCommune(_ commune: String) async throws -> [Travaux] {
        let allTravaux = try await fetchTravaux()
        return allTravaux.filter { $0.commune.lowercased().contains(commune.lowercased()) }
    }
    
    func fetchTravauxTresPerturbants() async throws -> [Travaux] {
        let allTravaux = try await fetchTravaux()
        return allTravaux.filter { $0.importance == .tresPerturbant }
    }
}

enum TravauxServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL invalide"
        case .invalidResponse:
            return "Réponse invalide du serveur"
        case .httpError(let code):
            return "Erreur HTTP: \(code)"
        case .decodingError(let error):
            return "Erreur de décodage: \(error.localizedDescription)"
        }
    }
}
