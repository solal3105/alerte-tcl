import Foundation

/// Charge la liste des trottinettes Dott disponibles à Lyon via le worker proxy.
/// Cache 60 s côté app, aligné avec le TTL du worker.
actor DottService {
    static let shared = DottService()
    private init() {}

    private let endpoint = NetworkConfiguration.proxyBaseURL + "/dott-vehicles"

    private let cacheValidity: TimeInterval = 60
    private var cached: [DottVehicle]?
    private var cacheTimestamp: Date?

    /// Renvoie la liste des véhicules Dott. Filtre les `is_disabled` car
    /// non-utilisables, garde les `is_reserved` (affichés différemment côté UI).
    func fetchVehicles(forceRefresh: Bool = false) async throws -> [DottVehicle] {
        if !forceRefresh,
           let cached,
           let ts = cacheTimestamp,
           Date().timeIntervalSince(ts) < cacheValidity {
            return cached
        }

        guard let url = URL(string: endpoint) else { throw DottError.invalidURL }
        let request = NetworkConfiguration.request(url: url, timeout: NetworkConfiguration.heavyTimeout)
        let (data, response) = try await NetworkConfiguration.heavy.data(for: request)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw DottError.httpError(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(DottFeedResponse.self, from: data)
        let vehicles = decoded.data.bikes
            .compactMap(DottVehicle.init(feed:))
            .filter { !$0.isDisabled }

        cached = vehicles
        cacheTimestamp = Date()
        return vehicles
    }
}

enum DottError: LocalizedError {
    case invalidURL
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:          return "URL Dott invalide"
        case .httpError(let code): return "Erreur Dott (HTTP \(code))"
        }
    }
}
