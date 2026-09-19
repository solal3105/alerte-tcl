import CoreLocation
import Foundation

/// Position pour les widgets qui en ont besoin (station Vélo'v la plus proche, travaux autour de moi).
///
/// Elle suppose l'autorisation « pendant l'utilisation » donnée à l'application et l'accord pour
/// les widgets (`NSWidgetWantsLocation` dans l'Info.plist de l'extension) ; sinon elle rend `nil`.
@MainActor
final class WidgetLocation: NSObject {
    /// Une position récente, ou `nil` si elle est refusée ou introuvable dans le délai.
    static func current(timeout: TimeInterval = 8) async -> CLLocation? {
        await WidgetLocation().request(timeout: timeout)
    }

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    private var isAuthorized: Bool {
        let status = manager.authorizationStatus
        return (status == .authorizedWhenInUse || status == .authorizedAlways) && manager.isAuthorizedForWidgetUpdates
    }

    private func request(timeout: TimeInterval) async -> CLLocation? {
        guard isAuthorized else { return nil }
        if let last = manager.location, Date().timeIntervalSince(last.timestamp) < 5 * 60 {
            return last
        }
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                self?.finish(with: self?.manager.location)
            }
        }
    }

    private func finish(with location: CLLocation?) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: location)
    }
}

extension WidgetLocation: @preconcurrency CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        finish(with: locations.last)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        AppLogger.debug("Position pour le widget refusée : \(error.localizedDescription)", category: .widget)
        finish(with: manager.location)
    }
}
