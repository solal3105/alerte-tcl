import Foundation
import SwiftUI
import Combine
import CoreLocation
import MapKit

@MainActor
final class LiveVehiclesViewModel: ObservableObject {
    @Published var vehicles: [Vehicle] = []
    /// Non-@Published: mis à jour à chaque fetch (30 s) mais relu à chaque tick
    /// de l'`AnimationClock` (~15 fps) depuis `LiveMapView.mapContent`, donc
    /// pas besoin de déclencher `objectWillChange` pour faire rafraîchir la vue.
    /// Eviter de publier ce dict (~1000 entrées) économise des invalidations SwiftUI.
    var animatedVehicles: [String: AnimatedVehicle] = [:]
    @Published var busLines: [BusLine] = []
    @Published var transitLines: [TransitLine] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastUpdate: Date?
    @Published var selectedVehicleType: VehicleType? {
        didSet {
            updateFilteredVehicles()
            updateClustersIfNeeded()
        }
    }
    @Published var selectedLine: String? {
        didSet {
            updateFilteredVehicles()
            updateClustersIfNeeded()
        }
    }
    @Published var selectedLines: Set<String> = []
    @Published var showBusLines = true
    @Published var showTransitLines = true
    @Published var mapRegion: MKCoordinateRegion
    @Published var currentZoomLevel: Double = 0.15
    @Published var visibleRegion: MKCoordinateRegion?
    @Published var isInitialLoadComplete = false
    @Published var isLive = false
    
    // Transit Stops
    @Published var transitStops: [TransitStop] = []
    @Published var mergedStops: [MergedStop] = [] // Arrêts fusionnés (< 30m)
    @Published var isLoadingStops = false
    
    // Cached computed properties for performance
    @Published private(set) var filteredVehicles: [Vehicle] = []
    @Published private(set) var visibleMergedStops: [MergedStop] = []
    
    private var streamTask: Task<Void, Never>?
    private var regionUpdateTask: Task<Void, Never>?
    private var consecutiveErrors = 0
    /// L'API SIRI Lite TCL ne publie de nouvelles positions que toutes les 30 s.
    /// Fetcher plus souvent renvoie les mêmes données → CPU/réseau/batterie gaspillés.
    /// L'interpolation côté client fait le liant entre deux fetchs.
    private let baseInterval: TimeInterval = 30
    private let maxInterval: TimeInterval = 60
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
    /// 0.08 = vue très large, clustering activé seulement quand on voit presque toute la métropole
    private let vehicleClusteringZoomThreshold: Double = 0.08
    
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
    
    func loadBusLines() async {
        do {
            busLines = try await BusLineService.shared.fetchBusLines()
            AppLogger.debug("✅ ViewModel: \(busLines.count) lignes C chargées")
            AppLogger.debug("✅ ViewModel: showBusLines = \(showBusLines)")
        } catch {
            AppLogger.debug("❌ Erreur chargement lignes de bus: \(error)")
        }
    }
    
    func loadTransitLines() async {
        do {
            transitLines = try await TransitLineService.shared.fetchTransitLines()
            AppLogger.debug("✅ ViewModel: \(transitLines.count) lignes de transport chargées")
            AppLogger.debug("✅ ViewModel: showTransitLines = \(showTransitLines)")
        } catch {
            AppLogger.debug("❌ Erreur chargement lignes de transport: \(error)")
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
                
                vehicles = mergeWithGracePeriodVehicles(fetchedVehicles)
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
                AppLogger.debug("⚠️ Erreur SIRI tentative \(attempt)/\(attempts): \(siriError.errorDescription ?? "inconnue")")
            } catch {
                lastError = error
                AppLogger.debug("⚠️ Erreur véhicules tentative \(attempt)/\(attempts): \(error.localizedDescription)")
            }
            
            // Retry avec délai seulement si ce n'est pas la dernière tentative
            if attempt < attempts {
                AppLogger.debug("🔄 Retry véhicules dans 2s...")
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
        let now = CACurrentMediaTime()
        // Lu une fois par cycle (évite N appels cross-process à UIAccessibility).
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        var updated: [String: AnimatedVehicle] = [:]
        updated.reserveCapacity(newVehicles.count)
        
        for vehicle in newVehicles {
            if let existing = animatedVehicles[vehicle.id] {
                existing.updateTarget(vehicle: vehicle, duration: baseInterval, currentTime: now, reduceMotion: reduceMotion)
                existing.lastSeenAt = Date()
                existing.isActive = true
                updated[vehicle.id] = existing
            } else {
                updated[vehicle.id] = AnimatedVehicle(vehicle: vehicle)
            }
        }
        
        // Période de grâce pour les véhicules temporairement absents
        for (id, animated) in animatedVehicles where updated[id] == nil {
            if !animated.shouldBeRemoved {
                animated.isActive = false
                updated[id] = animated
            }
        }
        
        animatedVehicles = updated
        
        if isFirstLoad {
            isFirstLoad = false
        }
    }
    
    /// Fusionne les véhicules fraîchement récupérés avec ceux en période de grâce
    /// pour éviter le clignotement des véhicules au terminus.
    private func mergeWithGracePeriodVehicles(_ fetched: [Vehicle]) -> [Vehicle] {
        let fetchedIds = Set(fetched.map { $0.id })
        let graceVehicles = animatedVehicles.values
            .filter { !$0.isActive && !fetchedIds.contains($0.id) }
            .map { $0.lastVehicle }
        return fetched + graceVehicles
    }
    
    
    // MARK: - Live Data Stream
    
    private var adaptiveInterval: TimeInterval {
        guard consecutiveErrors > 0 else { return baseInterval }
        return min(baseInterval * pow(1.5, Double(consecutiveErrors)), maxInterval)
    }
    
    func startLiveStream() {
        // Si le stream tourne déjà, ne pas le redémarrer inutilement
        // (évite le freeze de l'animationTask lors de transitions .inactive → .active)
        guard !isLive else { return }
        isLive = true
        consecutiveErrors = 0
        
        // Boucle de fetch
        streamTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                
                let fetchStart = Date()
                await self.fetchVehiclesQuietly()
                let fetchDuration = Date().timeIntervalSince(fetchStart)
                
                // Pipeline: subtract fetch time from interval so total cycle = adaptiveInterval
                let wait = max(self.adaptiveInterval - fetchDuration, 2.0)
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            }
        }
    }
    
    func stopLiveStream() {
        streamTask?.cancel()
        streamTask = nil
        isLive = false
    }
    
    private func fetchVehiclesQuietly() async {
        do {
            let fetched = try await SIRILiteService.shared.fetchVehiclePositions()
            updateAnimatedVehicles(with: fetched)
            vehicles = mergeWithGracePeriodVehicles(fetched)
            lastUpdate = Date()
            error = nil
            consecutiveErrors = 0
            
            updateFilteredVehicles()
            updateClustersIfNeeded(force: shouldShowClusters)
        } catch {
            consecutiveErrors += 1
            // Only surface error after 3 consecutive failures (transient tolerance)
            if consecutiveErrors >= 3 {
                self.error = (error as? SIRIError)?.errorDescription ?? error.localizedDescription
            }
            AppLogger.debug("⚠️ Stream fetch error (\(consecutiveErrors)): \(error.localizedDescription)")
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
        currentZoomLevel <= stopsZoomThreshold
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
            
            AppLogger.debug("✅ ViewModel: \(stops.count) arrêts → \(merged.count) arrêts fusionnés")
            
            // Mettre à jour sur le MainActor
            await MainActor.run {
                transitStops = stops
                mergedStops = merged
                updateVisibleStops()
            }
        } catch is TaskTimeoutError {
            AppLogger.debug("⏱️ Timeout arrêts (\(NetworkConfiguration.heavyTimeout)s)")
        } catch {
            AppLogger.debug("⚠️ Erreur arrêts (non-bloquante): \(error.localizedDescription)")
        }
    }
    
    func loadAllPassagesForStop(stopId: Int) async {
        guard let index = transitStops.firstIndex(where: { $0.id == stopId }) else {
            AppLogger.debug("⚠️ ViewModel: Arrêt \(stopId) non trouvé")
            return
        }
        
        guard !transitStops[index].isLoadingPassages else {
            AppLogger.debug("⏳ ViewModel: Chargement déjà en cours pour arrêt \(stopId)")
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
            AppLogger.debug("✅ ViewModel: \(passages.count) passages chargés pour arrêt \(stopId)")
        } catch is TaskTimeoutError {
            AppLogger.debug("⏱️ Timeout passages arrêt \(stopId) (\(NetworkConfiguration.fastTimeout)s)")
        } catch {
            AppLogger.debug("⚠️ Erreur passages arrêt \(stopId) (non-bloquante): \(error.localizedDescription)")
        }
    }
    
    deinit {
        streamTask?.cancel()
    }
}
