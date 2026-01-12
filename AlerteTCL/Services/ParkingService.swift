import Foundation

actor ParkingService {
    static let shared = ParkingService()
    
    private let baseURL = "https://data.grandlyon.com/geoserver/ogc/features/v1/collections"
    
    private init() {}
    
    func fetchParkings() async throws -> [Parking] {
        // Utiliser l'API Features (plus moderne, pas d'authentification requise)
        let urlString = "\(baseURL)/metropole-de-lyon:parkings-de-la-metropole-de-lyon-disponibilites-temps-reel-v2/items?f=application/json&sortby=gid"
        
        guard let url = URL(string: urlString) else {
            print("❌ ParkingService: URL invalide")
            throw ParkingServiceError.invalidURL
        }
        
        print("🌐 ParkingService: URL de chargement: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("AlerteTCL/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ ParkingService: Réponse invalide")
            throw ParkingServiceError.invalidResponse
        }
        
        print("📡 ParkingService: Status code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            print("❌ ParkingService: Erreur HTTP \(httpResponse.statusCode)")
            throw ParkingServiceError.httpError(httpResponse.statusCode)
        }
        
        // Debug: afficher les premières lignes de la réponse
        if let jsonString = String(data: data, encoding: .utf8) {
            let preview = String(jsonString.prefix(500))
            print("📄 ParkingService: Réponse JSON (preview): \(preview)...")
        }
        
        let decoder = JSONDecoder()
        let parkingResponse = try decoder.decode(ParkingResponse.self, from: data)
        
        print("✅ ParkingService: \(parkingResponse.features.count) parkings chargés")
        
        let parkings = parkingResponse.features.map { Parking(from: $0) }
        print("🅿️ ParkingService: Exemples: \(parkings.prefix(3).map { $0.nom })")
        
        return parkings
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
