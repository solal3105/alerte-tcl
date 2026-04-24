import Foundation

actor TCLAPIService {
    static let shared = TCLAPIService()
    
    // Proxy Cloudflare Worker — les credentials Grand Lyon sont stockés
    // côté Cloudflare en secrets chiffrés, jamais dans le binaire de l'app.
    private let alertsEndpoint = NetworkConfiguration.proxyBaseURL + "/alerts"
    
    private init() {}
    
    func fetchAlerts() async throws -> [TCLAlert] {
        guard let url = URL(string: alertsEndpoint) else {
            AppLogger.debug("❌ TCLAPIService: URL invalide")
            throw APIError.invalidURL
        }
        
        AppLogger.debug("🌐 TCLAPIService: Chargement des alertes depuis le proxy")
        
        var request = NetworkConfiguration.request(url: url, timeout: NetworkConfiguration.fastTimeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("AlerteTCL/1.0", forHTTPHeaderField: "User-Agent")
        AppLogger.debug("🚀 Alertes: Début requête (timeout: \(NetworkConfiguration.fastTimeout)s)")
        
        // Pas d'auth côté app — le proxy Cloudflare gère les credentials
        
        let (data, response) = try await NetworkConfiguration.fast.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            AppLogger.debug("❌ TCLAPIService: Réponse invalide")
            throw APIError.invalidResponse
        }
        
        AppLogger.debug("📡 TCLAPIService: Status code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                AppLogger.debug("❌ TCLAPIService: Authentification échouée")
                throw APIError.unauthorized
            }
            AppLogger.debug("❌ TCLAPIService: Erreur HTTP \(httpResponse.statusCode)")
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        do {
            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(APIResponse.self, from: data)
            AppLogger.debug("✅ TCLAPIService: \(apiResponse.values.count) alertes chargées")
            
            // Filtrer les alertes actives
            let activeAlerts = apiResponse.values.filter { $0.isActive }
            AppLogger.debug("📊 TCLAPIService: \(activeAlerts.count) alertes actives")
            
            return activeAlerts
        } catch {
            AppLogger.debug("❌ TCLAPIService: Erreur de décodage: \(error)")
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
