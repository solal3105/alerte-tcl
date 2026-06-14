import Foundation

/// Charge et met en cache le mapping code opérationnel SIRI → nom commercial TCL.
/// Source : endpoint /line-mapping du proxy (construit depuis code_ligne des datasets GeoServer).
/// Exemple : "3082" → "213", "4252" → "C202"
actor LineCodeMappingService {
    static let shared = LineCodeMappingService()

    private let url = NetworkConfiguration.proxyBaseURL + "/line-mapping"
    private let cacheValidityDuration: TimeInterval = 86400

    private var mapping: [String: String] = [:]
    private var cacheTimestamp: Date?

    private init() {}

    /// Codes absents de GeoServer mais connus — mapping statique de dernier recours.
    private static let staticFallback: [String: String] = [
        "7601": "N1",   // Navigone N1 (bateau-bus Confluences)
    ]

    /// Retourne le nom commercial pour un code SIRI opérationnel, ou nil si déjà commercial.
    func commercialName(for siriCode: String) async -> String? {
        await ensureLoaded()
        return mapping[siriCode]
    }

    /// Résout un code SIRI : retourne le nom commercial si un mapping existe, sinon le code tel quel.
    func resolve(_ siriCode: String) async -> String {
        await ensureLoaded()
        return mapping[siriCode] ?? siriCode
    }

    /// Retourne le dictionnaire de mapping complet (chargé si nécessaire).
    func loadMapping() async -> [String: String] {
        await ensureLoaded()
        return mapping
    }

    private func ensureLoaded() async {
        if let ts = cacheTimestamp, Date().timeIntervalSince(ts) < cacheValidityDuration {
            return
        }
        do {
            try await load()
        } catch {
            AppLogger.debug("⚠️ LineCodeMappingService: impossible de charger le mapping — \(error)", category: .service)
        }
    }

    private func load() async throws {
        guard let endpoint = URL(string: url) else { throw ServiceError.invalidURL }
        var request = NetworkConfiguration.request(url: endpoint, timeout: NetworkConfiguration.sharedTimeout)
        request.setValue("AlerteTCL/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await NetworkConfiguration.session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw ServiceError.invalidResponse
        }

        struct LineMappingResponse: Decodable {
            let mapping: [String: String]
        }
        let decoded = try JSONDecoder().decode(LineMappingResponse.self, from: data)
        // Merge static fallbacks pour les lignes absentes de GeoServer
        var merged = Self.staticFallback
        merged.merge(decoded.mapping) { _, remote in remote }
        mapping = merged
        cacheTimestamp = Date()
        AppLogger.debug("✅ LineCodeMappingService: \(mapping.count) entrées chargées", category: .service)
    }
}
