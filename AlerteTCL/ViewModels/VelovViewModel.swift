import Foundation
import MapKit
import Shared

/// Stations Vélo'v sur la carte : rechargées toutes les minutes tant que la couche est activée,
/// limitées à la zone visible comme les arrêts. Le réglage est conservé entre deux lancements.
@MainActor
final class VelovViewModel: ObservableObject {
    @Published private(set) var visibleStations: [VelovStation] = []
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.persistenceKey)
            if isEnabled { startRefreshing() } else { stopRefreshing() }
        }
    }

    /// Ne compter que les vélos électriques (nombre et couleur des marqueurs). Conservé entre deux lancements.
    @Published var electricOnly: Bool {
        didSet { UserDefaults.standard.set(electricOnly, forKey: Self.electricKey) }
    }

    private static let persistenceKey = "liveMap.showVelov"
    private static let electricKey = "liveMap.velovElectricOnly"
    /// Même seuil de zoom que les arrêts : au-delà, la carte serait couverte de stations.
    private let zoomThreshold: Double = 0.03
    private var stations: [VelovStation] = []
    private var lastZoom: Double = 0.15
    private var lastRegion: MKCoordinateRegion?
    private var refreshTask: Task<Void, Never>?

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.persistenceKey)
        electricOnly = UserDefaults.standard.bool(forKey: Self.electricKey)
        if isEnabled { startRefreshing() }
    }

    /// Appelé par la carte à chaque changement de région.
    func updateVisible(zoom: Double, region: MKCoordinateRegion) {
        lastZoom = zoom
        lastRegion = region
        Task { @MainActor in applyVisibleFilter() }
    }

    private func applyVisibleFilter() {
        guard isEnabled, lastZoom <= zoomThreshold, let region = lastRegion else {
            if !visibleStations.isEmpty { visibleStations = [] }
            return
        }
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2
        visibleStations = stations.filter { $0.lat >= minLat && $0.lat <= maxLat && $0.lng >= minLon && $0.lng <= maxLon }
    }

    private func startRefreshing() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
    }

    private func stopRefreshing() {
        refreshTask?.cancel()
        refreshTask = nil
        stations = []
        visibleStations = []
    }

    private func refresh() async {
        do {
            stations = try await VelovService.companion.shared.fetchStations(forceRefresh: false)
            applyVisibleFilter()
        } catch {
            AppLogger.debug("⚠️ Stations Vélo'v indisponibles : \(error.localizedDescription)")
        }
    }
}
