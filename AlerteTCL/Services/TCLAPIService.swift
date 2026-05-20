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
            throw ServiceError.invalidURL
        }
        
        AppLogger.debug("🌐 TCLAPIService: Chargement des alertes depuis le proxy")
        
        var request = NetworkConfiguration.request(url: url, timeout: NetworkConfiguration.fastTimeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("AlerteTCL/1.0", forHTTPHeaderField: "User-Agent")
        AppLogger.debug("🚀 Alertes: Début requête (timeout: \(NetworkConfiguration.fastTimeout)s)")
        
        // Pas d'auth côté app — le proxy Cloudflare gère les credentials
        
        let (data, response) = try await NetworkConfiguration.session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            AppLogger.debug("❌ TCLAPIService: Réponse invalide")
            throw ServiceError.invalidResponse
        }
        
        AppLogger.debug("📡 TCLAPIService: Status code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                AppLogger.debug("❌ TCLAPIService: Authentification échouée")
                throw ServiceError.unauthorized
            }
            AppLogger.debug("❌ TCLAPIService: Erreur HTTP \(httpResponse.statusCode)")
            throw ServiceError.httpError(httpResponse.statusCode)
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
            throw ServiceError.decodingError(error)
        }
    }
}

