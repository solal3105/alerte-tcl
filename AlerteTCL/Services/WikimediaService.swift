import Foundation

/// Recherche des photos de véhicules sur Wikimedia Commons (CC-BY-SA).
/// API publique, sans clé. Politique d'usage : https://www.mediawiki.org/wiki/API:Etiquette
enum WikimediaService {
    private static let baseURL = "https://commons.wikimedia.org/w/api.php"
    private static var cache: [String: [URL]] = [:]

    /// Retourne les URLs de thumbnails (400 px) pour le modèle donné, triées par index.
    static func fetchPhotos(for model: String) async -> [URL] {
        if let cached = cache[model] { return cached }

        let query = "\(model) TCL"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)?action=query&generator=search&gsrnamespace=6&gsrsearch=\(encoded)&gsrlimit=8&prop=imageinfo&iiprop=url&iiurlwidth=400&format=json") else {
            return []
        }

        var request = URLRequest(url: url, timeoutInterval: 8)
        // Wikimedia API policy : User-Agent obligatoire avec contact
        request.setValue("AlerteTCL/1.0 (iOS; contact@alertetcl.fr)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
            let result = try JSONDecoder().decode(WikimediaResponse.self, from: data)
            guard let pages = result.query?.pages else {
                cache[model] = []
                return []
            }
            let urls = pages.values
                .sorted { ($0.index ?? Int.max) < ($1.index ?? Int.max) }
                .compactMap { $0.imageinfo?.first?.thumburl }
                .compactMap { URL(string: $0) }
            cache[model] = urls
            return urls
        } catch {
            return []
        }
    }

    // MARK: - DTOs

    private struct WikimediaResponse: Decodable {
        let query: WikimediaQuery?
    }

    private struct WikimediaQuery: Decodable {
        let pages: [String: WikimediaPage]
    }

    private struct WikimediaPage: Decodable {
        let index: Int?
        let imageinfo: [WikimediaImageInfo]?
    }

    private struct WikimediaImageInfo: Decodable {
        let thumburl: String?
    }
}
