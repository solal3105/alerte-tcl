import Foundation

actor TCLAPIService {
    static let shared = TCLAPIService()
    
    private let alertsEndpoint = "https://download.data.grandlyon.com/ws/rdata/tcl_sytral.tclalertetrafic_2/all.json"
    
    private var credentials: (username: String, password: String)? {
        SecretsManager.grandLyonCredentials
    }
    
    private init() {}
    
    func fetchAlerts() async throws -> [TCLAlert] {
        guard let url = URL(string: alertsEndpoint) else {
            print("❌ TCLAPIService: URL invalide")
            throw APIError.invalidURL
        }
        
        print("🌐 TCLAPIService: Chargement des alertes depuis \(alertsEndpoint)")
        
        var request = NetworkConfiguration.request(url: url, timeout: NetworkConfiguration.fastTimeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("AlerteTCL/1.0", forHTTPHeaderField: "User-Agent")
        print("🚀 Alertes: Début requête (timeout: \(NetworkConfiguration.fastTimeout)s)")
        
        // Ajouter l'authentification Basic Auth
        if let creds = credentials {
            let credString = "\(creds.username):\(creds.password)"
            if let credentialsData = credString.data(using: .utf8) {
                let base64Credentials = credentialsData.base64EncodedString()
                request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
            }
        }
        
        let (data, response) = try await NetworkConfiguration.fast.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ TCLAPIService: Réponse invalide")
            throw APIError.invalidResponse
        }
        
        print("📡 TCLAPIService: Status code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                print("❌ TCLAPIService: Authentification échouée")
                throw APIError.unauthorized
            }
            print("❌ TCLAPIService: Erreur HTTP \(httpResponse.statusCode)")
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        do {
            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(APIResponse.self, from: data)
            print("✅ TCLAPIService: \(apiResponse.values.count) alertes chargées")
            
            // Filtrer les alertes actives
            let activeAlerts = apiResponse.values.filter { $0.isActive }
            print("📊 TCLAPIService: \(activeAlerts.count) alertes actives")
            
            return activeAlerts
        } catch {
            print("❌ TCLAPIService: Erreur de décodage: \(error)")
            throw APIError.decodingError(error)
        }
    }
    
    func fetchAlertsForLines(_ lineIds: [String]) async throws -> [TCLAlert] {
        let allAlerts = try await fetchAlerts()
        return allAlerts.filter { alert in
            lineIds.contains(alert.ligneCom) || lineIds.contains(alert.ligneCli)
        }
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case notFound
    case serverError(Int)
    case decodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL invalide"
        case .invalidResponse:
            return "Réponse invalide du serveur"
        case .unauthorized:
            return "Accès non autorisé - Clé API requise"
        case .notFound:
            return "Données non trouvées"
        case .serverError(let code):
            return "Erreur serveur (\(code))"
        case .decodingError:
            return "Erreur de décodage des données"
        case .networkError(let error):
            return "Erreur réseau: \(error.localizedDescription)"
        }
    }
}
