import Foundation
import SwiftUI
import MapKit
import Combine

/// ViewModel de l'onglet "Mobilités douces".
///
/// Aujourd'hui : stations Vélo'v + trottinettes Dott (free-floating).
/// L'utilisateur bascule entre les deux services via une pile de pills en haut
/// de l'écran. Les deux jeux de données sont chargés et rafraîchis indépendamment
/// pour que le toggle soit instantané.
@MainActor
final class SoftMobilityViewModel: ObservableObject {
    // MARK: - Service actif

    @Published var activeService: Service = .velov

    enum Service: String, CaseIterable, Identifiable {
        case velov = "Vélo'v"
        case dott  = "Dott"
        var id: String { rawValue }

        var icon: String {
            switch self {
            case .velov: return "bicycle"
            case .dott:  return "scooter"
            }
        }
    }

    // MARK: - Vélo'v

    @Published private(set) var velovStations: [VelovStation] = []
    @Published private(set) var velovError: String?
    @Published private(set) var velovLastUpdate: Date?
    @Published private(set) var isLoadingVelov = false

    /// Filtre actif pour Vélo'v - ne masque jamais de stations, change juste la métrique
    /// affichée sur le marqueur.
    @Published var velovFilter: VelovStationFilter = .all

    let velovRefreshInterval: TimeInterval = 30

    // MARK: - Dott

    @Published private(set) var dottVehicles: [DottVehicle] = []
    @Published private(set) var dottError: String?
    @Published private(set) var dottLastUpdate: Date?
    @Published private(set) var isLoadingDott = false

    /// Masque les trottinettes en batterie faible (<20%) - utile pour ne voir
    /// que les véhicules réellement utilisables sur un trajet correct.
    @Published var dottHideLowBattery = false

    let dottRefreshInterval: TimeInterval = 60

    // MARK: - Map state (clustering)

    @Published var currentZoomLevel: Double = 0.08
    @Published var visibleRegion: MKCoordinateRegion?

    private let clusteringConfig: ClusteringEngine.Configuration = .dense

    // MARK: - Tasks

    private var velovRefreshTask: Task<Void, Never>?
    private var dottRefreshTask: Task<Void, Never>?

    // MARK: - Statut combiné

    var error: String? {
        switch activeService {
        case .velov: return velovError
        case .dott:  return dottError
        }
    }

    var lastUpdate: Date? {
        switch activeService {
        case .velov: return velovLastUpdate
        case .dott:  return dottLastUpdate
        }
    }

    var isLoading: Bool {
        switch activeService {
        case .velov: return isLoadingVelov
        case .dott:  return isLoadingDott
        }
    }

    var refreshInterval: TimeInterval {
        switch activeService {
        case .velov: return velovRefreshInterval
        case .dott:  return dottRefreshInterval
        }
    }

    // MARK: - Vélo'v helpers

    var totalAvailableBikes: Int {
        velovStations.reduce(0) { $0 + $1.availableBikes }
    }

    var totalAvailableStands: Int {
        velovStations.reduce(0) { $0 + $1.availableStands }
    }

    var openStationsCount: Int {
        velovStations.filter { $0.status.isOperational }.count
    }

    func count(for station: VelovStation, filter: VelovStationFilter) -> Int {
        guard station.status.isOperational else { return 0 }
        switch filter {
        case .all:        return station.availableBikes
        case .mechanical: return station.availableMechanicalBikes
        case .electrical: return station.availableElectricalBikes
        case .stands:     return station.availableStands
        }
    }

    func color(for station: VelovStation, filter: VelovStationFilter) -> MarkerColor {
        guard station.status.isOperational else { return .closed }
        let value = count(for: station, filter: filter)
        if value == 0 { return .empty }
        if value <= 2 { return .low }
        return .ok
    }

    func searchStations(query: String, near userLocation: CLLocation?) -> [VelovStation] {
        let needle = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespaces)
        let base: [VelovStation]
        if needle.isEmpty {
            base = velovStations
        } else {
            base = velovStations.filter { station in
                let haystack = "\(station.displayName) \(station.address ?? "") \(station.commune ?? "")"
                    .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                return haystack.contains(needle)
            }
        }
        guard let userLocation else {
            return base.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        }
        return base.sorted { a, b in
            let da = CLLocation(latitude: a.coordinate.latitude, longitude: a.coordinate.longitude)
                .distance(from: userLocation)
            let db = CLLocation(latitude: b.coordinate.latitude, longitude: b.coordinate.longitude)
                .distance(from: userLocation)
            return da < db
        }
    }

    // MARK: - Dott helpers

    /// Liste filtrée (batterie faible cachée si l'option est active).
    var filteredDottVehicles: [DottVehicle] {
        dottHideLowBattery
            ? dottVehicles.filter { $0.batteryLevel != .low }
            : dottVehicles
    }

    var dottAvailableCount: Int { filteredDottVehicles.count }
    var dottLowBatteryCount: Int { dottVehicles.filter { $0.batteryLevel == .low }.count }

    /// Trottinettes visibles dans le viewport actuel (avec buffer). Si pas de viewport
    /// défini, on prend tout. Ce filtre évite de clusteriser inutilement le pays entier.
    var dottInViewport: [DottVehicle] {
        let base = filteredDottVehicles
        guard let region = visibleRegion else { return base }
        let bufferedLatDelta = region.span.latitudeDelta * 1.5
        let bufferedLonDelta = region.span.longitudeDelta * 1.5
        let minLat = region.center.latitude - bufferedLatDelta / 2
        let maxLat = region.center.latitude + bufferedLatDelta / 2
        let minLon = region.center.longitude - bufferedLonDelta / 2
        let maxLon = region.center.longitude + bufferedLonDelta / 2
        return base.filter { v in
            let lat = v.coordinate.latitude
            let lon = v.coordinate.longitude
            return lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon
        }
    }

    /// Résultat de clustering pour Dott - clusters + véhicules individuels.
    /// Si on est zoomé fort (sous le seuil), aucun clustering : on rend tout.
    var dottClustering: (clusters: [MapCluster<DottVehicle>], individuals: [DottVehicle]) {
        let items = dottInViewport
        if !ClusteringEngine.shouldCluster(zoomLevel: currentZoomLevel) {
            return ([], items)
        }
        let result = ClusteringEngine.createClusters(
            from: items,
            zoomLevel: currentZoomLevel,
            config: clusteringConfig
        )
        return (result.clusters, result.unclustered)
    }

    // MARK: - Lifecycle

    func onAppear() {
        Task { await loadVelov() }
        Task { await loadDott() }
        startAutoRefresh()
    }

    func onDisappear() {
        velovRefreshTask?.cancel()
        dottRefreshTask?.cancel()
        velovRefreshTask = nil
        dottRefreshTask = nil
    }

    func refresh() async {
        switch activeService {
        case .velov: await loadVelov(forceRefresh: true)
        case .dott:  await loadDott(forceRefresh: true)
        }
    }

    func updateZoom(_ span: MKCoordinateSpan) {
        currentZoomLevel = span.latitudeDelta
    }

    func updateVisibleRegion(_ region: MKCoordinateRegion) {
        visibleRegion = region
    }

    // MARK: - Loading

    private func loadVelov(forceRefresh: Bool = false) async {
        isLoadingVelov = true
        defer { isLoadingVelov = false }
        do {
            let stations = try await VelovService.shared.fetchStations(forceRefresh: forceRefresh)
            self.velovStations = stations
            self.velovLastUpdate = Date()
            self.velovError = nil
        } catch {
            self.velovError = error.localizedDescription
            AppLogger.debug("⚠️ Erreur chargement Vélo'v: \(error.localizedDescription)")
        }
    }

    private func loadDott(forceRefresh: Bool = false) async {
        isLoadingDott = true
        defer { isLoadingDott = false }
        do {
            let vehicles = try await DottService.shared.fetchVehicles(forceRefresh: forceRefresh)
            self.dottVehicles = vehicles
            self.dottLastUpdate = Date()
            self.dottError = nil
        } catch {
            self.dottError = error.localizedDescription
            AppLogger.debug("⚠️ Erreur chargement Dott: \(error.localizedDescription)")
        }
    }

    private func startAutoRefresh() {
        velovRefreshTask?.cancel()
        velovRefreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self.velovRefreshInterval * 1_000_000_000))
                if Task.isCancelled { return }
                await self.loadVelov(forceRefresh: true)
            }
        }
        dottRefreshTask?.cancel()
        dottRefreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self.dottRefreshInterval * 1_000_000_000))
                if Task.isCancelled { return }
                await self.loadDott(forceRefresh: true)
            }
        }
    }

    // MARK: - Types

    enum VelovStationFilter: String, CaseIterable, Identifiable {
        case all         = "Disponibles"
        case mechanical  = "Mécaniques"
        case electrical  = "Électriques"
        case stands      = "Bornettes"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .all:         return "circle.grid.2x2.fill"
            case .mechanical:  return "bicycle"
            case .electrical:  return "bolt.fill"
            case .stands:      return "parkingsign"
            }
        }

        var caption: String {
            switch self {
            case .all:         return "Tous les vélos disponibles"
            case .mechanical:  return "Vélos mécaniques disponibles"
            case .electrical:  return "Vélos électriques disponibles"
            case .stands:      return "Bornettes libres pour déposer un vélo"
            }
        }
    }

    enum MarkerColor {
        case ok        // bonne dispo (≥ 3)
        case low       // faible (1-2)
        case empty     // 0
        case closed    // station fermée

        var color: Color {
            switch self {
            case .ok:     return .green
            case .low:    return .orange
            case .empty:  return .gray
            case .closed: return Color(.systemGray2)
            }
        }
    }
}
