import Foundation

actor TravauxService {
    static let shared = TravauxService()
    
    // Nouveau endpoint OGC Features pour "Travaux engagés sur la Métropole de Lyon"
    private let baseURL = "https://data.grandlyon.com/geoserver/ogc/features/v1/collections/metropole-de-lyon:lyv_lyvia.lyvchantier/items"
    
    private init() {}
    
    func fetchTravaux() async throws -> [Travaux] {
        // Utiliser le nouveau endpoint OGC Features API
        let urlString = "\(baseURL)?f=application/json&limit=500"
        
        guard let url = URL(string: urlString) else {
            print("❌ TravauxService: URL invalide")
            throw TravauxServiceError.invalidURL
        }
        
        print("🌐 TravauxService: URL de chargement: \(url.absoluteString)")
        
        var request = NetworkConfiguration.request(url: url, timeout: NetworkConfiguration.sharedTimeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("AlerteTCL/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await NetworkConfiguration.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ TravauxService: Réponse invalide")
            throw TravauxServiceError.invalidResponse
        }
        
        print("📡 TravauxService: Status code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            print("❌ TravauxService: Erreur HTTP \(httpResponse.statusCode)")
            throw TravauxServiceError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let travauxResponse = try decoder.decode(TravauxResponse.self, from: data)
        
        print("✅ TravauxService: \(travauxResponse.features.count) chantiers chargés")
        
        let travaux = travauxResponse.features.map { Travaux(from: $0) }
        
        // Filtrer les chantiers actifs (en cours ou prévus)
        let activeTravaux = travaux.filter { $0.isActive }
        print("🚧 TravauxService: \(activeTravaux.count) chantiers actifs")
        
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
