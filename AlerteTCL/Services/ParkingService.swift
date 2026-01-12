import Foundation

actor ParkingService {
    static let shared = ParkingService()
    
    private let baseURL = "https://data.grandlyon.com/geoserver/metropole-de-lyon/ows"
    
    private init() {}
    
    func fetchParkings() async throws -> [Parking] {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "SERVICE", value: "WFS"),
            URLQueryItem(name: "VERSION", value: "2.0.0"),
            URLQueryItem(name: "request", value: "GetFeature"),
            URLQueryItem(name: "typename", value: "metropole-de-lyon:parkings-de-la-metropole-de-lyon-disponibilites-temps-reel-v2"),
            URLQueryItem(name: "outputFormat", value: "application/json"),
            URLQueryItem(name: "SRSNAME", value: "EPSG:4171"),
            URLQueryItem(name: "sortBy", value: "gid")
        ]
        
        guard let url = components.url else {
            throw ParkingServiceError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ParkingServiceError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ParkingServiceError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let parkingResponse = try decoder.decode(ParkingResponse.self, from: data)
        
        return parkingResponse.features.map { Parking(from: $0) }
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
