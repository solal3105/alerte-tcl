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
    @Published var mergedStops: [MergedStop] = [] // Arrêts fusionnés (< 30m)
    @Published var isLoadingStops = false
    @Published var showTransitStops = true
    
    // Cached computed properties for performance
    @Published private(set) var filteredVehicles: [Vehicle] = []
    @Published private(set) var visibleMergedStops: [MergedStop] = []
    
    private var refreshTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?
    private var regionUpdateTask: Task<Void, Never>?
    private let refreshInterval: TimeInterval = 15
    private var cancellables = Set<AnyCancellable>()
    private var isFirstLoad = true
    
    private var cachedAvailableLines: [String] = []
    private var lastVehicleCount: Int = 0
    
    let favoriteLinesService = FavoriteLinesService.shared
        
    private static let lyonCenter = CLLocationCoordinate2D(latitude: 45.764043, longitude: 4.835659)
    private static let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    
    static let clusteringZoomThreshold: Double = 0.02
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
    
    private func updateFilteredVehicles() {
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
        
        filteredVehicles = result
    }
    
    @Published private(set) var cachedClusters: [MapCluster<Vehicle>] = []
    @Published private(set) var cachedUnclusteredVehicles: [Vehicle] = []
    private var lastClusteringZoom: Double = 0
    private var lastClusteringVehicleCount: Int = 0
    
    /// Seuil de zoom pour activer le clustering (très dézoomé seulement)
    /// 0.04 = vue très large, clustering activé seulement à ce niveau (divisé par 2 pour apparaître plus tard au dézoom)
    private let vehicleClusteringZoomThreshold: Double = 0.04
    
    var shouldShowClusters: Bool {
        currentZoomLevel >= vehicleClusteringZoomThreshold
    }
    
    private func updateClustersIfNeeded(force: Bool = false) {
        // Ne recalculer que si le zoom ou le nombre de véhicules a changé significativement
        let zoomChanged = abs(currentZoomLevel - lastClusteringZoom) > 0.005
        let vehiclesChanged = filteredVehicles.count != lastClusteringVehicleCount
        
        guard force || zoomChanged || vehiclesChanged else { return }
        
        // Pas de clustering sauf si très dézoomé
        if !shouldShowClusters {
            cachedClusters = []
            cachedUnclusteredVehicles = filteredVehicles
            lastClusteringZoom = currentZoomLevel
            lastClusteringVehicleCount = filteredVehicles.count
            return
        }
        
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
    
    /// Nombre max de retries automatiques pour le chargement initial
    private static let maxRetries = 1
    private static let retryDelay: UInt64 = 2_000_000_000 // 2s
    
    func loadVehicles() async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        defer {
            // TOUJOURS remettre isLoading à false, quoi qu'il arrive
            isLoading = false
        }
        
        var lastError: Error?
        let attempts = isInitialLoadComplete ? 1 : (Self.maxRetries + 1)
        
        for attempt in 1...attempts {
            do {
                let fetchedVehicles = try await SIRILiteService.shared.fetchVehiclePositions()
                
                updateAnimatedVehicles(with: fetchedVehicles)
                
                vehicles = fetchedVehicles
                lastUpdate = Date()
                error = nil
                isInitialLoadComplete = true
                
                // Mettre à jour les véhicules filtrés et clusters
                updateFilteredVehicles()
                // Forcer la mise à jour des clusters pour actualiser leur position quand les véhicules bougent
                updateClustersIfNeeded(force: shouldShowClusters)
                return
            } catch let siriError as SIRIError {
                lastError = siriError
                print("⚠️ Erreur SIRI tentative \(attempt)/\(attempts): \(siriError.errorDescription ?? "inconnue")")
            } catch {
                lastError = error
                print("⚠️ Erreur véhicules tentative \(attempt)/\(attempts): \(error.localizedDescription)")
            }
            
            // Retry avec délai seulement si ce n'est pas la dernière tentative
            if attempt < attempts {
                print("🔄 Retry véhicules dans 2s...")
                try? await Task.sleep(nanoseconds: Self.retryDelay)
            }
        }
        
        // Toutes les tentatives ont échoué
        if let siriError = lastError as? SIRIError {
            self.error = siriError.errorDescription
        } else {
            self.error = lastError?.localizedDescription
        }
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
                existingAnimated.lastSeenAt = Date()
                existingAnimated.isActive = true
                updatedVehicles[vehicle.id] = existingAnimated
            } else {
                // ✅ Créer un nouveau véhicule animé seulement s'il n'existe pas
                let animated = AnimatedVehicle(vehicle: vehicle)
                updatedVehicles[vehicle.id] = animated
            }
        }
        
        // ✅ Garder les véhicules qui ont disparu temporairement (période de grâce anti-clignotement)
        for (id, animated) in animatedVehicles {
            if updatedVehicles[id] == nil {
                // Véhicule absent de la réponse API
                if !animated.shouldBeRemoved {
                    // Encore dans la période de grâce - le garder visible mais arrêter l'animation
                    animated.isActive = false
                    animated.stopAnimation() // Libérer les ressources CADisplayLink
                    updatedVehicles[id] = animated
                } else {
                    // Période de grâce expirée - supprimer définitivement
                    animated.stopAnimation()
                }
            }
        }
        
        animatedVehicles = updatedVehicles
        
        if isFirstLoad {
            isFirstLoad = false
        }
    }
    
    
    func startAutoRefresh() {
        stopAutoRefresh()
        
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                guard self.isAutoRefreshEnabled else { return }
                await self.loadVehicles()
                try? await Task.sleep(nanoseconds: UInt64(self.refreshInterval * 1_000_000_000))
            }
        }
        
        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                guard self.isAutoRefreshEnabled else { return }
                let startTime = Date()
                while !Task.isCancelled {
                    guard self.isAutoRefreshEnabled else { return }
                    let elapsed = Date().timeIntervalSince(startTime)
                    let progress = min(elapsed / self.refreshInterval, 1.0)
                    let remaining = max(0, self.refreshInterval - elapsed)
                    
                    self.refreshProgress = progress
                    self.secondsUntilNextRefresh = Int(ceil(remaining))
                    
                    if elapsed >= self.refreshInterval {
                        break
                    }
                    
                    // ⚠️ Mise à jour toutes les 500ms au lieu de 100ms pour réduire la charge MainActor
                    try? await Task.sleep(nanoseconds: 500_000_000)
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
    }
    
    /// Seuil de changement de région pour déclencher une mise à jour (évite micro-mouvements)
    private let regionChangeThreshold: Double = 0.0001
    private var lastProcessedRegion: MKCoordinateRegion?
    
    func updateVisibleRegion(_ region: MKCoordinateRegion) {
        visibleRegion = region
        
        // Early exit si le changement est trop petit (micro-mouvements)
        if let last = lastProcessedRegion {
            let latChange = abs(region.center.latitude - last.center.latitude)
            let lonChange = abs(region.center.longitude - last.center.longitude)
            let spanChange = abs(region.span.latitudeDelta - last.span.latitudeDelta)
            
            if latChange < regionChangeThreshold && 
               lonChange < regionChangeThreshold && 
               spanChange < regionChangeThreshold * 10 {
                return // Changement trop petit, ignorer
            }
        }
        
        // Annuler la mise à jour précédente
        regionUpdateTask?.cancel()
        
        // Debounce de 100ms (réduit de 150ms) avec early-exit ci-dessus
        regionUpdateTask = Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard !Task.isCancelled else { return }
            
            lastProcessedRegion = region
            updateFilteredVehicles()
            updateVisibleStops()
            updateClustersIfNeeded()
        }
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
        updateFilteredVehicles()
        updateClustersIfNeeded()
    }
    
    func clearFilters() {
        selectedVehicleType = nil
        selectedLine = nil
        selectedLines.removeAll()
        updateFilteredVehicles()
        updateClustersIfNeeded()
    }
    
    // MARK: - Transit Stops
    
    /// Zoom threshold pour afficher les arrêts - aligné sur le seuil de clustering (0.01)
    /// Plus le latitudeDelta est petit, plus on est zoomé
    private let stopsZoomThreshold: Double = ClusteringEngine.clusteringZoomThreshold
    
    var shouldShowStops: Bool {
        showTransitStops && currentZoomLevel <= stopsZoomThreshold
    }
    
    private func updateVisibleStops() {
        guard shouldShowStops, let region = visibleRegion else {
            visibleMergedStops = []
            return
        }
        // Filtrer les arrêts fusionnés dans le viewport
        visibleMergedStops = mergedStops.filter { stop in
            let lat = stop.coordinate.latitude
            let lon = stop.coordinate.longitude
            let minLat = region.center.latitude - region.span.latitudeDelta / 2
            let maxLat = region.center.latitude + region.span.latitudeDelta / 2
            let minLon = region.center.longitude - region.span.longitudeDelta / 2
            let maxLon = region.center.longitude + region.span.longitudeDelta / 2
            return lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon
        }
    }
    
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
            // Charger les arrêts avec timeout
            let stops = try await Task.withTimeout(seconds: NetworkConfiguration.heavyTimeout) {
                try await TransitStopService.shared.fetchAllStops()
            }
            
            // ⚠️ CRITIQUE: Fusionner les arrêts HORS du MainActor (traitement lourd)
            let merged = await Task.detached(priority: .userInitiated) {
                StopMergingEngine.mergeNearbyStops(stops)
            }.value
            
            print("✅ ViewModel: \(stops.count) arrêts → \(merged.count) arrêts fusionnés")
            
            // Mettre à jour sur le MainActor
            await MainActor.run {
                transitStops = stops
                mergedStops = merged
                updateVisibleStops()
            }
        } catch is TaskTimeoutError {
            print("⏱️ Timeout arrêts (\(NetworkConfiguration.heavyTimeout)s)")
        } catch {
            print("⚠️ Erreur arrêts (non-bloquante): \(error.localizedDescription)")
        }
    }
    
    func loadAllPassagesForStop(stopId: Int) async {
        guard let index = transitStops.firstIndex(where: { $0.id == stopId }) else {
            print("⚠️ ViewModel: Arrêt \(stopId) non trouvé")
            return
        }
        
        guard !transitStops[index].isLoadingPassages else {
            print("⏳ ViewModel: Chargement déjà en cours pour arrêt \(stopId)")
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
            print("✅ ViewModel: \(passages.count) passages chargés pour arrêt \(stopId)")
        } catch is TaskTimeoutError {
            print("⏱️ Timeout passages arrêt \(stopId) (\(NetworkConfiguration.fastTimeout)s)")
        } catch {
            print("⚠️ Erreur passages arrêt \(stopId) (non-bloquante): \(error.localizedDescription)")
        }
    }
    
    deinit {
        refreshTask?.cancel()
    }
}
