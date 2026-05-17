import Foundation
import SwiftUI
import MapKit
import Combine

/// ViewModel de l'onglet "Mobilités douces".
///
/// Aujourd'hui : stations Vélo'v.
/// À venir : trottinettes / vélos en free-floating (Dott, …) — le ViewModel est
/// pensé pour héberger plusieurs services côte à côte sans devoir le refactorer.
@MainActor
final class SoftMobilityViewModel: ObservableObject {
    @Published private(set) var velovStations: [VelovStation] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdate: Date?
    @Published private(set) var error: String?

    /// Filtre actif — change la métrique affichée sur les marqueurs.
    /// Les stations ne sont JAMAIS masquées par ce filtre.
    @Published var filter: StationFilter = .all

    /// Auto-refresh — calé sur le TTL du worker pour ne pas marteler le proxy.
    let refreshInterval: TimeInterval = 30
    private var refreshTask: Task<Void, Never>?

    // MARK: - Stats globales

    /// Vélos totaux disponibles sur le réseau (méca + élec).
    var totalAvailableBikes: Int {
        velovStations.reduce(0) { $0 + $1.availableBikes }
    }

    /// Bornettes libres sur le réseau.
    var totalAvailableStands: Int {
        velovStations.reduce(0) { $0 + $1.availableStands }
    }

    var openStationsCount: Int {
        velovStations.filter { $0.status.isOperational }.count
    }

    // MARK: - Affichage par filtre

    /// Valeur à afficher sur le marqueur pour ce filtre.
    /// Station fermée → toujours 0.
    func count(for station: VelovStation, filter: StationFilter) -> Int {
        guard station.status.isOperational else { return 0 }
        switch filter {
        case .all:        return station.availableBikes
        case .mechanical: return station.availableMechanicalBikes
        case .electrical: return station.availableElectricalBikes
        case .stands:     return station.availableStands
        }
    }

    /// Couleur du marqueur selon le filtre actif et la valeur correspondante.
    func color(for station: VelovStation, filter: StationFilter) -> MarkerColor {
        guard station.status.isOperational else { return .closed }
        let value = count(for: station, filter: filter)
        if value == 0 { return .empty }
        if value <= 2 { return .low }
        return .ok
    }

    // MARK: - Recherche

    /// Filtre par texte pour la feuille de recherche (insensible casse/accents).
    /// `userLocation` permet de trier par distance si disponible.
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

    // MARK: - Lifecycle

    func onAppear() {
        Task { await loadVelov() }
        startAutoRefresh()
    }

    func onDisappear() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refresh() async {
        await loadVelov(forceRefresh: true)
    }

    // MARK: - Loading

    private func loadVelov(forceRefresh: Bool = false) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let stations = try await VelovService.shared.fetchStations(forceRefresh: forceRefresh)
            self.velovStations = stations
            self.lastUpdate = Date()
            self.error = nil
        } catch {
            self.error = error.localizedDescription
            AppLogger.debug("⚠️ Erreur chargement Vélo'v: \(error.localizedDescription)")
        }
    }

    private func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self.refreshInterval * 1_000_000_000))
                if Task.isCancelled { return }
                await self.loadVelov(forceRefresh: true)
            }
        }
    }

    // MARK: - Types

    enum StationFilter: String, CaseIterable, Identifiable {
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
        case low       // faible (1–2)
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
