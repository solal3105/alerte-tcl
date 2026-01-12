import Foundation
import MapKit
import SwiftUI

@MainActor
final class StopsViewModel: ObservableObject {
    // Inputs/state
    @Published var showStops: Bool = false
    @Published private(set) var currentZoomLevel: Double = 0.15
    @Published private(set) var region: MKCoordinateRegion?
    
    // Outputs
    @Published private(set) var stops: [StopAnnotation] = []
    
    // Threshold to start showing stops (smaller span = closer zoom)
    // Tune as needed to balance performance and visibility.
    private let zoomThreshold: Double = 0.06
    
    // Simple in-flight load control
    private var loadTask: Task<Void, Never>?
    
    var shouldShowStops: Bool {
        showStops && currentZoomLevel <= zoomThreshold
    }
    
    func toggleStopsDisplay() {
        showStops.toggle()
    }
    
    func updateZoomLevel(_ span: MKCoordinateSpan) {
        currentZoomLevel = span.latitudeDelta
    }
    
    func loadStops(in region: MKCoordinateRegion) async {
        // Save last region
        self.region = region
        
        // If we shouldn't show stops, clear and bail
        guard shouldShowStops else {
            stops = []
            return
        }
        
        // Cancel any previous load
        loadTask?.cancel()
        
        loadTask = Task { [weak self] in
            guard let self else { return }
            
            // Fetch stops aggregated from live vehicles in the region
            let stopWithVehicles = await StopTimesService.shared.fetchStopsWithVehicles(in: region)
            
            // Map to StopAnnotation
            let annotations: [StopAnnotation] = stopWithVehicles.map { entry in
                let stop = Stop(
                    id: entry.stopRef,
                    stopId: entry.stopRef,
                    name: entry.stopName,
                    latitude: entry.coordinate.latitude,
                    longitude: entry.coordinate.longitude
                )
                
                // Build passages from vehicles’ nextPassages for this stop
                let passages = entry.nextPassages
                return StopAnnotation(
                    id: entry.stopRef,
                    stop: stop,
                    passages: passages
                )
            }
            
            // Publish
            self.stops = annotations
        }
        
        await loadTask?.value
    }
}
