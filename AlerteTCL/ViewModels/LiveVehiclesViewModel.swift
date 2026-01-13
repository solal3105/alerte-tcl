import Foundation
import SwiftUI
import Combine
import CoreLocation
import MapKit

@MainActor
final class LiveVehiclesViewModel: ObservableObject {
    @Published var vehicles: [Vehicle] = []
    @Published var animatedVehicles: [String: AnimatedVehicle] = [:]
    @Published var busLines: [BusLine] = []
    @Published var transitLines: [TransitLine] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastUpdate: Date?
    @Published var selectedVehicleType: VehicleType?
    @Published var selectedLine: String?
    @Published var selectedLines: Set<String> = []
    @Published var showBusLines = true
    @Published var showTransitLines = true
    @Published var mapRegion: MKCoordinateRegion
    @Published var isAutoRefreshEnabled = true
    @Published var currentZoomLevel: Double = 0.15
    @Published var refreshProgress: Double = 0.0
    @Published var visibleRegion: MKCoordinateRegion?
    @Published var secondsUntilNextRefresh: Int = 15
    @Published var isInitialLoadComplete = false
    
    // Transit Stops
    @Published var transitStops: [TransitStop] = []
    @Published var isLoadingStops = false
    @Published var showTransitStops = true
    
    private var refreshTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?
    private let refreshInterval: TimeInterval = 15
    private var cancellables = Set<AnyCancellable>()
    private var isFirstLoad = true
    
    private var cachedAvailableLines: [String] = []
    private var lastVehicleCount: Int = 0
    
    let favoriteLinesService = FavoriteLinesService.shared
        
    private static let lyonCenter = CLLocationCoordinate2D(latitude: 45.764043, longitude: 4.835659)
    private static let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    
    static let clusteringZoomThreshold: Double = 0.08
    private let clusteringConfig = ClusteringEngine.Configuration.default
    
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
        
        LocationService.shared.$currentLocation
            .compactMap { $0 }
            .first()
            .sink { [weak self] location in
                guard let self = self else { return }
                withAnimation {
                    self.mapRegion = MKCoordinateRegion(
                        center: location.coordinate,
                        span: Self.defaultSpan
                    )
                }
            }
            .store(in: &cancellables)
    }
    
    var filteredVehicles: [Vehicle] {
        var result = vehicles
        
        if let type = selectedVehicleType {
            result = result.filter { $0.vehicleType == type }
        }
        
        if let line = selectedLine, !line.isEmpty {
            result = result.filter { $0.lineName == line }
        } else if !selectedLines.isEmpty {
            result = result.filter { selectedLines.contains($0.lineName) }
        }
        
        // Filtrage viewport avec buffer standard
        result = result.visibleIn(region: visibleRegion, buffer: .standard)
        
        return result
    }
    
    @Published private(set) var cachedClusters: [MapCluster<Vehicle>] = []
    @Published private(set) var cachedUnclusteredVehicles: [Vehicle] = []
    private var lastClusteringZoom: Double = 0
    private var lastClusteringVehicleCount: Int = 0
    
    var shouldShowClusters: Bool {
        ClusteringEngine.shouldCluster(zoomLevel: currentZoomLevel, config: clusteringConfig)
    }
    
    private func updateClustersIfNeeded() {
        // Ne recalculer que si le zoom ou le nombre de véhicules a changé significativement
        let zoomChanged = abs(currentZoomLevel - lastClusteringZoom) > 0.005
        let vehiclesChanged = filteredVehicles.count != lastClusteringVehicleCount
        
        guard zoomChanged || vehiclesChanged else { return }
        
        let result = ClusteringEngine.createClusters(from: filteredVehicles, zoomLevel: currentZoomLevel, config: clusteringConfig)
        cachedClusters = result.clusters
        cachedUnclusteredVehicles = result.unclustered
        lastClusteringZoom = currentZoomLevel
        lastClusteringVehicleCount = filteredVehicles.count
    }
    
    var clusters: [MapCluster<Vehicle>] {
        cachedClusters
    }
    
    var unclusteredVehicles: [Vehicle] {
        cachedUnclusteredVehicles
    }
    
    // MARK: - Display Limits
    
    private let maxDisplayMarkers = 1000
    
    var shouldShowTooManyMarkersWarning: Bool {
        // Compter TOUS les véhicules filtrés (pas les markers)
        return filteredVehicles.count > maxDisplayMarkers
    }
    
    var displayClusters: [MapCluster<Vehicle>] {
        guard !shouldShowTooManyMarkersWarning else { return [] }
        return clusters
    }
    
    var displayVehicles: [Vehicle] {
        guard !shouldShowTooManyMarkersWarning else { return [] }
        return unclusteredVehicles
    }
    
    var vehiclesByType: [VehicleType: [Vehicle]] {
        Dictionary(grouping: filteredVehicles) { $0.vehicleType }
    }
    
    var availableLines: [String] {
        if vehicles.count != lastVehicleCount {
            cachedAvailableLines = computeAvailableLines()
            lastVehicleCount = vehicles.count
        }
        
        let linesToFilter: [Vehicle]
        if let type = selectedVehicleType {
            linesToFilter = vehicles.filter { $0.vehicleType == type }
            let filtered = Set(linesToFilter.map { $0.lineName })
            return cachedAvailableLines.filter { filtered.contains($0) }
        }
        
        return cachedAvailableLines
    }
    
    private func computeAvailableLines() -> [String] {
        let uniqueLines = Array(Set(vehicles.map { $0.lineName }))
        
        let lineInfo = uniqueLines.compactMap { line -> (line: String, type: VehicleType, numericValue: Int)? in
            guard let vehicle = vehicles.first(where: { $0.lineName == line }) else { return nil }
            let numericValue = Int(line.filter { $0.isNumber }) ?? Int.max
            return (line, vehicle.vehicleType, numericValue)
        }
        
        return lineInfo.sorted { a, b in
            if a.type.sortOrder != b.type.sortOrder {
                return a.type.sortOrder < b.type.sortOrder
            }
            if a.numericValue != b.numericValue {
                return a.numericValue < b.numericValue
            }
            return a.line < b.line
        }.map { $0.line }
    }
    
    func getFilteredLines(searchText: String) -> [String] {
        let lines = availableLines
        if searchText.isEmpty {
            return lines
        }
        return lines.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    func getSortedLinesWithFavorites(searchText: String) -> (favorites: [String], others: [String]) {
        let filtered = getFilteredLines(searchText: searchText)
        let favorites = filtered.filter { favoriteLinesService.isFavorite($0) }
        let others = filtered.filter { !favoriteLinesService.isFavorite($0) }
        return (favorites, others)
    }
    
    func vehicleTypeForLine(_ line: String) -> VehicleType? {
        vehicles.first { $0.lineName == line }?.vehicleType
    }
    
    var vehicleTypeStats: [(type: VehicleType, count: Int)] {
        VehicleType.allCases
            .map { type in (type: type, count: vehicles.filter { $0.vehicleType == type }.count) }
            .filter { $0.count > 0 }
            .sorted { $0.type.sortOrder < $1.type.sortOrder }
    }
    
    func loadBusLines() async {
        do {
            busLines = try await BusLineService.shared.fetchBusLines()
            #if DEBUG
            print("✅ ViewModel: \(busLines.count) lignes C chargées")
            print("✅ ViewModel: showBusLines = \(showBusLines)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Erreur chargement lignes de bus: \(error)")
            #endif
        }
    }
    
    func loadTransitLines() async {
        do {
            transitLines = try await TransitLineService.shared.fetchTransitLines()
            #if DEBUG
            print("✅ ViewModel: \(transitLines.count) lignes de transport chargées")
            print("✅ ViewModel: showTransitLines = \(showTransitLines)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Erreur chargement lignes de transport: \(error)")
            #endif
        }
    }
    
    func loadVehicles() async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        do {
            let fetchedVehicles = try await SIRILiteService.shared.fetchVehiclePositions()
            
            updateAnimatedVehicles(with: fetchedVehicles)
            
            vehicles = fetchedVehicles
            lastUpdate = Date()
            error = nil
            isInitialLoadComplete = true
            
            // Forcer la mise à jour des clusters après chargement
            updateClustersIfNeeded()
        } catch let siriError as SIRIError {
            self.error = siriError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func updateAnimatedVehicles(with newVehicles: [Vehicle]) {
        var updatedVehicles: [String: AnimatedVehicle] = [:]
        
        for vehicle in newVehicles {
            if let existingAnimated = animatedVehicles[vehicle.id] {
                // ✅ Mettre à jour la cible sans recréer l'objet
                let previousVehicle = vehicles.first { $0.id == vehicle.id }
                existingAnimated.updateTarget(
                    newVehicle: vehicle,
                    previousCoordinate: previousVehicle?.coordinate,
                    previousBearing: previousVehicle?.bearing
                )
                updatedVehicles[vehicle.id] = existingAnimated
            } else {
                // ✅ Créer un nouveau véhicule animé seulement s'il n'existe pas
                let animated = AnimatedVehicle(vehicle: vehicle)
                updatedVehicles[vehicle.id] = animated
            }
        }
        
        // ✅ Nettoyer les véhicules qui ont disparu
        for (id, animated) in animatedVehicles {
            if updatedVehicles[id] == nil {
                animated.stopAnimation()
            }
        }
        
        animatedVehicles = updatedVehicles
        
        if isFirstLoad {
            isFirstLoad = false
        }
    }
    
    
    func startAutoRefresh() {
        stopAutoRefresh()
        
        refreshTask = Task {
            while !Task.isCancelled && isAutoRefreshEnabled {
                await loadVehicles()
                try? await Task.sleep(nanoseconds: UInt64(refreshInterval * 1_000_000_000))
            }
        }
        
        progressTask = Task {
            while !Task.isCancelled && isAutoRefreshEnabled {
                let startTime = Date()
                while !Task.isCancelled {
                    let elapsed = Date().timeIntervalSince(startTime)
                    let progress = min(elapsed / refreshInterval, 1.0)
                    let remaining = max(0, refreshInterval - elapsed)
                    await MainActor.run {
                        self.refreshProgress = progress
                        self.secondsUntilNextRefresh = Int(ceil(remaining))
                    }
                    
                    if elapsed >= refreshInterval {
                        break
                    }
                    
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
            }
        }
    }
    
    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
        progressTask?.cancel()
        progressTask = nil
        
        for (_, animated) in animatedVehicles {
            animated.stopAnimation()
        }
    }
    
    func updateZoomLevel(_ span: MKCoordinateSpan) {
        currentZoomLevel = span.latitudeDelta
        updateClustersIfNeeded()
    }
    
    func updateVisibleRegion(_ region: MKCoordinateRegion) {
        visibleRegion = region
        updateClustersIfNeeded()
    }
    
    func centerOnLyon() {
        withAnimation {
            mapRegion = MKCoordinateRegion(
                center: Self.lyonCenter,
                span: Self.defaultSpan
            )
        }
    }
    
    func centerOnVehicle(_ vehicle: Vehicle) {
        withAnimation {
            mapRegion = MKCoordinateRegion(
                center: vehicle.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }
    
    func toggleLineSelection(_ line: String) {
        if selectedLines.contains(line) {
            selectedLines.remove(line)
        } else {
            selectedLines.insert(line)
        }
    }
    
    func clearFilters() {
        selectedVehicleType = nil
        selectedLine = nil
        selectedLines.removeAll()
    }
    
    // MARK: - Transit Stops
    
    /// Zoom threshold pour afficher les arrêts (zoom fort = latitudeDelta petit)
    private let stopsZoomThreshold: Double = 0.008
    
    var shouldShowStops: Bool {
        showTransitStops && currentZoomLevel < stopsZoomThreshold
    }
    
    var visibleStops: [TransitStop] {
        guard shouldShowStops else { return [] }
        return transitStops.visibleIn(region: visibleRegion, buffer: .small)
    }
    
    func loadTransitStops() async {
        guard !isLoadingStops else { return }
        
        isLoadingStops = true
        
        do {
            let stops = try await TransitStopService.shared.fetchStopsWithPassages()
            transitStops = stops
            print("✅ ViewModel: \(stops.count) arrêts avec passages chargés")
        } catch {
            print("❌ Erreur chargement arrêts: \(error)")
        }
        
        isLoadingStops = false
    }
    
    func refreshStopPassages() async {
        do {
            let passagesByStop = try await TransitStopService.shared.fetchPassages()
            
            // Update passages in existing stops
            for i in transitStops.indices {
                if let passages = passagesByStop[transitStops[i].id] {
                    transitStops[i].passages = passages
                }
            }
            print("🔄 ViewModel: Passages rafraîchis pour \(passagesByStop.count) arrêts")
        } catch {
            print("❌ Erreur rafraîchissement passages: \(error)")
        }
    }
    
    deinit {
        refreshTask?.cancel()
    }
}
