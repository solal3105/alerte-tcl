import Foundation

actor ParkingService {
    static let shared = ParkingService()
    
    private let baseURL = "https://data.grandlyon.com/geoserver/ogc/features/v1/collections"
    private var cache: [ParkingType: (parkings: [Parking], timestamp: Date)] = [:]
    private let cacheValidityDuration: TimeInterval = 30 // 30 secondes pour les données temps réel
    
    private init() {}
    
    func fetchParkings(type: ParkingType = .car, forceRefresh: Bool = false) async throws -> [Parking] {
        // Vérifier le cache
        if !forceRefresh, let cached = cache[type] {
            let age = Date().timeIntervalSince(cached.timestamp)
            if age < cacheValidityDuration {
                print("✨ ParkingService: Utilisation du cache pour \(type.rawValue) (âge: \(Int(age))s)")
                return cached.parkings
            }
        }
        
        let collectionName: String
        
        switch type {
        case .car:
            collectionName = "metropole-de-lyon:parkings-de-la-metropole-de-lyon-disponibilites-temps-reel-v2"
        case .bike:
            collectionName = "metropole-de-lyon:pvo_patrimoine_voirie.pvostationnementvelo"
        case .motorized2Wheel:
            collectionName = "ville-de-lyon:vdl_deplacements.emplacement_moto"
        }
        
        let urlString = "\(baseURL)/\(collectionName)/items?f=application/json&sortby=gid"
        
        guard let url = URL(string: urlString) else {
            print("❌ ParkingService: URL invalide")
            throw ParkingServiceError.invalidURL
        }
        
        print("🌐 ParkingService: URL de chargement (\(type.rawValue)): \(url.absoluteString)")
        
        var request = NetworkConfiguration.request(url: url, timeout: NetworkConfiguration.sharedTimeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("AlerteTCL/1.0", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        let (data, response) = try await NetworkConfiguration.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ ParkingService: Réponse invalide")
            throw ParkingServiceError.invalidResponse
        }
        
        print("📡 ParkingService: Status code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            print("❌ ParkingService: Erreur HTTP \(httpResponse.statusCode)")
            throw ParkingServiceError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        
        do {
            let parkingResponse = try decoder.decode(ParkingResponse.self, from: data)
            print("✅ ParkingService: \(parkingResponse.features.count) parkings \(type.rawValue) chargés")
            
            let parkings = parkingResponse.features.map { Parking(from: $0, type: type) }
            print("🅿️ ParkingService: Exemples: \(parkings.prefix(3).map { $0.nom })")
            
            // Mettre en cache
            cache[type] = (parkings: parkings, timestamp: Date())
            
            return parkings
        } catch let decodingError as DecodingError {
            print("❌ ParkingService: Erreur de décodage détaillée:")
            switch decodingError {
            case .keyNotFound(let key, let context):
                print("  - Clé manquante: \(key.stringValue)")
                print("  - Chemin: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            case .typeMismatch(let type, let context):
                print("  - Type incorrect: attendu \(type)")
                print("  - Chemin: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            case .valueNotFound(let type, let context):
                print("  - Valeur manquante pour type: \(type)")
                print("  - Chemin: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            case .dataCorrupted(let context):
                print("  - Données corrompues")
                print("  - Chemin: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            @unknown default:
                print("  - Erreur inconnue: \(decodingError)")
            }
            throw ParkingServiceError.decodingError(decodingError)
        }
    }
    
    func fetchParkingsRelais() async throws -> [Parking] {
        let allParkings = try await fetchParkings()
        return allParkings.filter { parking in
            parking.nom.lowercased().contains("p+r") ||
            parking.nom.lowercased().contains("parc relais") ||
            parking.nom.lowercased().contains("park relais") ||
            parking.gestionnaire.lowercased().contains("tcl") ||
            parking.gestionnaire.lowercased().contains("sytral")
        }
    }
}

enum ParkingServiceError: LocalizedError {
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
