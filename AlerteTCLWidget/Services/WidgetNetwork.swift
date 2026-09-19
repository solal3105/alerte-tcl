import Foundation

enum WidgetNetworkError: Error {
    case invalidURL
    case badStatus(Int)
}

/// Réseau de l'extension : une seule session, courte, sans cache disque (les données sont du direct),
/// et un décodage JSON en une ligne pour chaque service.
enum WidgetNetwork {
    static let geoServerBase = "https://data.grandlyon.com/geoserver/ogc/features/v1/collections"

    static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        config.waitsForConnectivity = false
        config.urlCache = nil
        // Le relais n'accepte que les agents « AlerteTCL/… ».
        config.httpAdditionalHeaders = ["Accept": "application/json", "User-Agent": "AlerteTCL/1.0 (widget)"]
        return URLSession(configuration: config)
    }()

    static func data(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw WidgetNetworkError.badStatus(0) }
        guard (200..<300).contains(http.statusCode) else { throw WidgetNetworkError.badStatus(http.statusCode) }
        return data
    }

    static func json<T: Decodable>(_ type: T.Type, from string: String) async throws -> T {
        guard let url = URL(string: string) else { throw WidgetNetworkError.invalidURL }
        return try JSONDecoder().decode(type, from: try await data(from: url))
    }
}
