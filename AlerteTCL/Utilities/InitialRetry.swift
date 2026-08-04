import Foundation

/// Exécute `operation` avec retry (délai 2 s par défaut) réservé au chargement initial.
///
/// - Retourne `nil` si l'opération a été annulée (`CancellationError` / `URLError.cancelled`) :
///   annulation normale (sheet fermée, tâche remplacée), rien à afficher à l'utilisateur.
/// - Retourne `.success` dès qu'une tentative aboutit.
/// - Retourne `.failure` avec la dernière erreur une fois toutes les tentatives épuisées.
func withInitialRetry<T>(
    attempts: Int,
    retryDelay: UInt64 = 2_000_000_000,
    _ operation: () async throws -> T
) async -> Result<T, Error>? {
    var lastError: Error?
    let attempts = max(1, attempts)

    for attempt in 1...attempts {
        do {
            return .success(try await operation())
        } catch is CancellationError {
            AppLogger.debug("⏹️ Chargement annulé")
            return nil
        } catch let urlError as URLError where urlError.code == .cancelled {
            AppLogger.debug("⏹️ Requête annulée (URLError.cancelled)")
            return nil
        } catch {
            lastError = error
            AppLogger.debug("⚠️ Erreur tentative \(attempt)/\(attempts): \(error.localizedDescription)")
        }

        // Retry avec délai seulement si ce n'est pas la dernière tentative
        if attempt < attempts {
            AppLogger.debug("🔄 Retry dans \(retryDelay / 1_000_000_000)s...")
            try? await Task.sleep(nanoseconds: retryDelay)
        }
    }

    // Toutes les tentatives ont échoué : lastError est forcément renseignée ici
    guard let lastError else { return nil }
    return .failure(lastError)
}
