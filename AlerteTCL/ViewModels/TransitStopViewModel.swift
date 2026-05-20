import Foundation
import SwiftUI
import MapKit

@MainActor
final class TransitStopViewModel: ObservableObject {
    @Published var transitStops: [TransitStop] = []
    @Published var mergedStops: [MergedStop] = []
    @Published var isLoadingStops = false
    @Published private(set) var visibleMergedStops: [MergedStop] = []

    /// Non-@Published: updated by LiveMapRepresentable on every region change.
    /// Not UI state — no view observes these directly.
    var lastZoom: Double = 0.15
    var lastRegion: MKCoordinateRegion?

    private let stopsZoomThreshold: Double = 0.018

    // MARK: - Visibility

    /// Called by LiveMapRepresentable.Coordinator on regionDidChangeAnimated.
    func updateVisibleStops(zoom: Double, region: MKCoordinateRegion) {
        lastZoom = zoom
        lastRegion = region
        // Task breaks the synchronous UIKit delegate call stack, preventing
        // "@Published during view update" runtime warnings.
        Task { @MainActor in applyVisibleFilter() }
    }

    private func applyVisibleFilter() {
        guard lastZoom <= stopsZoomThreshold, let region = lastRegion else {
            visibleMergedStops = []
            return
        }
        let halfLatSpan = region.span.latitudeDelta / 2
        let halfLonSpan = region.span.longitudeDelta / 2
        let minLat = region.center.latitude - halfLatSpan
        let maxLat = region.center.latitude + halfLatSpan
        let minLon = region.center.longitude - halfLonSpan
        let maxLon = region.center.longitude + halfLonSpan
        visibleMergedStops = mergedStops.filter { stop in
            let lat = stop.coordinate.latitude
            let lon = stop.coordinate.longitude
            return lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon
        }
    }

    // MARK: - Loading

    func loadTransitStops() async {
        guard !isLoadingStops else { return }

        await MainActor.run {
            isLoadingStops = true
        }
        defer {
            Task { @MainActor in
                isLoadingStops = false
            }
        }

        do {
            let stops = try await Task.withTimeout(seconds: NetworkConfiguration.heavyTimeout) {
                try await TransitStopService.shared.fetchStops()
            }

            // ⚠️ CRITIQUE: Fusionner les arrêts HORS du MainActor (traitement lourd)
            let merged = await Task.detached(priority: .userInitiated) {
                StopMergingEngine.mergeNearbyStops(stops)
            }.value

            AppLogger.debug("✅ Stops: \(stops.count) arrêts → \(merged.count) arrêts fusionnés")

            await MainActor.run {
                transitStops = stops
                mergedStops = merged
                applyVisibleFilter()
            }
        } catch is TaskTimeoutError {
            AppLogger.debug("⏱️ Timeout arrêts (\(NetworkConfiguration.heavyTimeout)s)")
        } catch {
            AppLogger.debug("⚠️ Erreur arrêts (non-bloquante): \(error.localizedDescription)")
        }
    }

    func loadAllPassagesForStop(stopId: Int) async {
        guard let index = transitStops.firstIndex(where: { $0.id == stopId }) else {
            AppLogger.debug("⚠️ Stops: Arrêt \(stopId) non trouvé")
            return
        }

        guard !transitStops[index].isLoadingPassages else {
            AppLogger.debug("⏳ Stops: Chargement déjà en cours pour arrêt \(stopId)")
            return
        }

        transitStops[index].isLoadingPassages = true
        defer {
            if transitStops.indices.contains(index) {
                transitStops[index].isLoadingPassages = false
            }
        }

        do {
            let passages = try await Task.withTimeout(seconds: NetworkConfiguration.fastTimeout) {
                try await TransitStopService.shared.fetchPassagesForStop(stopId: stopId)
            }
            if transitStops.indices.contains(index) {
                transitStops[index].passages = passages
                transitStops[index].passagesLoaded = true
            }
            AppLogger.debug("✅ Stops: \(passages.count) passages chargés pour arrêt \(stopId)")
        } catch is TaskTimeoutError {
            AppLogger.debug("⏱️ Timeout passages arrêt \(stopId) (\(NetworkConfiguration.fastTimeout)s)")
        } catch {
            AppLogger.debug("⚠️ Erreur passages arrêt \(stopId) (non-bloquante): \(error.localizedDescription)")
        }
    }
}
