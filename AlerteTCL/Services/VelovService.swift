import Foundation

/// Service de chargement des stations Vélo'v.
///
/// L'endpoint Grand Lyon `jcd_jcdecaux.jcdvelov` fournit position + capacité +
/// disponibilité en temps réel dans une seule réponse, donc on n'a pas besoin
/// de fusion statique/temps-réel comme pour les P+R.
///
/// Cache mémoire 30 s — aligné avec le TTL du Cloudflare Worker.
actor VelovService {
    static let shared = VelovService()
    private init() {}

    // 447 stations à Lyon ; on prend une marge.
    private let endpoint = NetworkConfiguration.proxyBaseURL + "/velov?f=application/json&limit=600&sortby=gid"

    private let cacheValidity: TimeInterval = 30
    private var cached: [VelovStation]?
    private var cacheTimestamp: Date?

    /// Renvoie la liste des stations Vélo'v.
    /// Sert depuis le cache si la dernière requête date de moins de 30 s.
    func fetchStations(forceRefresh: Bool = false) async throws -> [VelovStation] {
        if !forceRefresh,
           let cached,
           let ts = cacheTimestamp,
           Date().timeIntervalSince(ts) < cacheValidity {
            return cached
        }

        guard let url = URL(string: endpoint) else { throw VelovError.invalidURL }
        let request = NetworkConfiguration.request(url: url, timeout: NetworkConfiguration.sharedTimeout)
        let (data, response) = try await NetworkConfiguration.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw VelovError.httpError(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(VelovResponse.self, from: data)
        let stations = decoded.features.compactMap(VelovStation.init(feature:))

        cached = stations
        cacheTimestamp = Date()
        return stations
    }
}

enum VelovError: LocalizedError {
    case invalidURL
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:           return "URL Vélo'v invalide"
        case .httpError(let code):  return "Erreur Vélo'v (HTTP \(code))"
        }
    }
}
