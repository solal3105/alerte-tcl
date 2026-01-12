import Foundation
import SwiftUI
import Combine
import CoreLocation
import MapKit

@MainActor
final class TrafficViewModel: ObservableObject {
    @Published var events: [TrafficEvent] = []
    @Published var segments: [TrafficSegment] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastUpdate: Date?
    
    @Published var showEvents = true
    @Published var showTrafficState = true
    @Published var selectedEventTypes: Set<TrafficEventType> = Set(TrafficEventType.allCases)
    @Published var selectedFluidity: Set<TrafficFluidity> = [.dense, .sature, .bloque, .inconnu] // Exclure .fluide par défaut
    
    @Published var mapRegion: MKCoordinateRegion
    @Published var currentZoomLevel: Double = 0.15
    
    private var refreshTask: Task<Void, Never>?
    private var filterTask: Task<Void, Never>?
    private let eventsRefreshInterval: TimeInterval = 60
    private let trafficRefreshInterval: TimeInterval = 180
    
    // Cache pour optimiser les performances
    private var cachedFilteredSegments: [TrafficSegment] = []
    private var lastFilteredRegion: MKCoordinateRegion?
    
    private static let lyonCenter = CLLocationCoordinate2D(latitude: 45.764043, longitude: 4.835659)
    private static let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    
    init() {
        if LocationService.shared.isLocationAvailable,
           let userLocation = LocationService.shared.currentLocation {
            self.mapRegion = MKCoordinateRegion(
                center: userLocation.coordinate,
                span: Self.defaultSpan
            )
        } else {
            self.mapRegion = MKCoordinateRegion(
                center: Self.lyonCenter,
                span: Self.defaultSpan
            )
        }
    }
    
    // MARK: - Computed Properties
    
    var filteredEvents: [TrafficEvent] {
        events.filter { selectedEventTypes.contains($0.eventType) }
    }
    
    var filteredSegments: [TrafficSegment] {
        // Utiliser le cache si la région n'a pas significativement changé
        if let lastRegion = lastFilteredRegion,
           abs(lastRegion.center.latitude - mapRegion.center.latitude) < 0.01 &&
           abs(lastRegion.center.longitude - mapRegion.center.longitude) < 0.01 &&
           abs(lastRegion.span.latitudeDelta - mapRegion.span.latitudeDelta) < 0.01 {
            return cachedFilteredSegments
        }
        
        return cachedFilteredSegments
    }
    
    func updateFilteredSegments() {
        // Annuler la tâche précédente
        filterTask?.cancel()
        
        // Créer une nouvelle tâche avec debounce
        filterTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            
            guard !Task.isCancelled else { return }
            
            let filtered = segments.filter { segment in
                // Filtrer par fluidité sélectionnée
                guard selectedFluidity.contains(segment.fluidity) else { return false }
                
                // Ne pas afficher les segments fluides (optimisation)
                guard segment.fluidity != .fluide else { return false }
                
                // Filtrer par viewport visible
                guard isSegmentInViewport(segment) else { return false }
                
                return true
            }
            
            cachedFilteredSegments = filtered
            lastFilteredRegion = mapRegion
        }
    }
    
    private func isSegmentInViewport(_ segment: TrafficSegment) -> Bool {
        // Calculer les bounds du viewport avec un buffer réduit
        let buffer = 0.3
        let latDelta = mapRegion.span.latitudeDelta * buffer
        let lonDelta = mapRegion.span.longitudeDelta * buffer
        
        let minLat = mapRegion.center.latitude - latDelta
        let maxLat = mapRegion.center.latitude + latDelta
        let minLon = mapRegion.center.longitude - lonDelta
        let maxLon = mapRegion.center.longitude + lonDelta
        
        // Optimisation : vérifier seulement le premier et dernier point
        // au lieu de tous les points du segment
        let coords = segment.clLocationCoordinates
        guard !coords.isEmpty else { return false }
        
        let firstInView = coords.first!.latitude >= minLat &&
                         coords.first!.latitude <= maxLat &&
                         coords.first!.longitude >= minLon &&
                         coords.first!.longitude <= maxLon
        
        let lastInView = coords.last!.latitude >= minLat &&
                        coords.last!.latitude <= maxLat &&
                        coords.last!.longitude >= minLon &&
                        coords.last!.longitude <= maxLon
        
        return firstInView || lastInView
    }
    
    var eventsByType: [TrafficEventType: Int] {
        Dictionary(grouping: events) { $0.eventType }
            .mapValues { $0.count }
    }
    
    var hasActiveFilters: Bool {
        selectedEventTypes.count < TrafficEventType.allCases.count ||
        selectedFluidity.count < TrafficFluidity.allCases.count ||
        !showEvents || !showTrafficState
    }
    
    // MARK: - Data Loading
    
    func loadData() async {
        isLoading = true
        error = nil
        
        async let eventsTask = loadEvents()
        async let segmentsTask = loadTrafficState()
        
        await eventsTask
        await segmentsTask
        
        lastUpdate = Date()
        isLoading = false
        
        // Mettre à jour le cache après le chargement
        updateFilteredSegments()
    }
    
    func loadEvents() async {
        do {
            let fetchedEvents = try await TrafficService.shared.fetchTrafficEvents()
            events = fetchedEvents
        } catch {
            #if DEBUG
            print("❌ Erreur chargement événements: \(error)")
            #endif
            self.error = error.localizedDescription
        }
    }
    
    func loadTrafficState() async {
        do {
            let fetchedSegments = try await TrafficService.shared.fetchTrafficState()
            segments = fetchedSegments
        } catch {
            #if DEBUG
            print("❌ Erreur chargement état trafic: \(error)")
            #endif
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - Auto Refresh
    
    func startAutoRefresh() {
        stopAutoRefresh()
        
        refreshTask = Task {
            while !Task.isCancelled {
                await loadData()
                try? await Task.sleep(nanoseconds: UInt64(eventsRefreshInterval * 1_000_000_000))
            }
        }
    }
    
    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
    
    // MARK: - Map Updates
    
    func updateZoomLevel(_ span: MKCoordinateSpan) {
        currentZoomLevel = span.latitudeDelta
    }
    
    func updateMapRegion(_ region: MKCoordinateRegion) {
        mapRegion = region
        updateFilteredSegments()
    }
    
    func centerOnUserLocation() {
        if let location = LocationService.shared.currentLocation {
            withAnimation {
                mapRegion = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            }
        }
    }
    
    // MARK: - Filters
    
    func toggleEventType(_ type: TrafficEventType) {
        if selectedEventTypes.contains(type) {
            selectedEventTypes.remove(type)
        } else {
            selectedEventTypes.insert(type)
        }
    }
    
    func toggleFluidity(_ fluidity: TrafficFluidity) {
        if selectedFluidity.contains(fluidity) {
            selectedFluidity.remove(fluidity)
        } else {
            selectedFluidity.insert(fluidity)
        }
    }
    
    func selectAllEventTypes() {
        selectedEventTypes = Set(TrafficEventType.allCases)
    }
    
    func deselectAllEventTypes() {
        selectedEventTypes = []
    }
    
    func selectAllFluidity() {
        selectedFluidity = Set(TrafficFluidity.allCases)
    }
    
    func deselectAllFluidity() {
        selectedFluidity = []
    }
    
    func resetFilters() {
        selectedEventTypes = Set(TrafficEventType.allCases)
        selectedFluidity = Set(TrafficFluidity.allCases)
        showEvents = true
        showTrafficState = true
    }
    
    deinit {
        refreshTask?.cancel()
    }
}
