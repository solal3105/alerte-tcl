import Foundation

/// Adresse du relais Cloudflare qui détient les identifiants Grand Lyon.
///
/// Membre de l'application et de l'extension widget : une seule adresse pour les deux,
/// mise à jour par `cloudflare-worker/deploy.sh` au déploiement.
enum ProxyEndpoint {
    static let baseURL = "https://tcl-proxy.solalgendrin.workers.dev"

    static func url(_ path: String) -> URL? {
        URL(string: baseURL + path)
    }
}
