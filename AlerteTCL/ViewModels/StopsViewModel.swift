import Foundation
import SwiftUI
import Combine
import CoreLocation
import MapKit

@MainActor
final class StopsViewModel: ObservableObject {
    @Published var stops: [StopAnnotation] = []
    @Published var isLoading = false
    @Published var selectedStop: StopAnnotation?
    @Published var showStops = false
    @Published var currentZoomLevel: Double = 0.15
    
    private var refreshTask: Task<Void, Never>?
    private let refreshInterval: TimeInterval = 30
    
    // Seuil de zoom pour afficher les arrêts (plus petit = plus zoomé)
    static let stopDisplayZoomThreshold: Double = 0.05
    
    var shouldShowStops: Bool {
        currentZoomLevel < Self.stopDisplayZoomThreshold && showStops
    }
    
    func loadStops(in region: MKCoordinateRegion) async {
        guard shouldShowStops else {
            stops = []
            return
        }
        
        isLoading = true
        
        let stopsWithVehicles = await StopTimesService.shared.fetchStopsWithVehicles(in: region)
        
        stops = stopsWithVehicles.map { stopWithVehicles in
            StopAnnotation(
                id: stopWithVehicles.stopRef,
                stop: Stop(
                    id: stopWithVehicles.stopRef,
                    stopId: stopWithVehicles.stopRef,
                    name: stopWithVehicles.stopName,
                    latitude: stopWithVehicles.coordinate.latitude,
                    longitude: stopWithVehicles.coordinate.longitude
                ),
                passages: stopWithVehicles.passages
            )
        }
        
        isLoading = false
    }
    
    func startAutoRefresh(region: MKCoordinateRegion) {
        stopAutoRefresh()
        
        refreshTask = Task {
            while !Task.isCancelled && showStops {
                await loadStops(in: region)
                try? await Task.sleep(nanoseconds: UInt64(refreshInterval * 1_000_000_000))
            }
        }
    }
    
    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
    
    func updateZoomLevel(_ span: MKCoordinateSpan) {
        currentZoomLevel = span.latitudeDelta
    }
    
    func toggleStopsDisplay() {
        showStops.toggle()
    }
    
    deinit {
        refreshTask?.cancel()
    }
}
