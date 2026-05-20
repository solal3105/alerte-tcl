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
            UserDefaults.standard.set(selectedVehicleType?.rawValue, forKey: PersistenceKey.selectedVehicleType)
            updateFilteredVehicles()
        }
    }
    @Published var selectedLine: String? {
        didSet { updateFilteredVehicles() }
    }
    @Published var selectedLines: Set<String> = [] {
        didSet {
            UserDefaults.standard.set(Array(selectedLines), forKey: PersistenceKey.selectedLines)
        }
    }
    @Published var showBusLines = true
    @Published var showTransitLines = true
    @Published var mapRegion: MKCoordinateRegion
    /// Non-@Published : lu par les moteurs de clustering/viewport mais pas par
    /// les Views SwiftUI (la carte est en UIKit). Publier ces deux propriétés
    /// invaliderait le body de `LiveMapView` à chaque mouvement de caméra
    /// (~60 Hz en glissement) et relancerait `updateUIView`.
    var currentZoomLevel: Double = 0.15
    var visibleRegion: MKCoordinateRegion?
    @Published var isInitialLoadComplete = false
    @Published var isLive = false
    
    // Cached computed properties for performance
    // `filteredVehicles` est un état interne : les vues lisent `displayVehicles`
    // (qui retourne `cachedUnclusteredVehicles`, lui-même @Published). Inutile
    // de déclencher une seconde publication par fetch.
    private(set) var filteredVehicles: [Vehicle] = []
    
    private var streamTask: Task<Void, Never>?
    private var regionUpdateTask: Task<Void, Never>?
    private var consecutiveErrors = 0
    /// L'API SIRI Lite TCL publie de nouvelles positions toutes les ~15 s.
    /// On fetch à 15 s pour aligner avec le TTL du cache Cloudflare (15 s) :
    /// chaque requête retourne des données fraîches. Grand Lyon reçoit ≤ 1 req/15 s.
    private let baseInterval: TimeInterval = 15
    private let maxInterval: TimeInterval = 60
    private var cancellables = Set<AnyCancellable>()
    private var isFirstLoad = true
    
    private var cachedAvailableLines: [String] = []
    private var lastVehicleCount: Int = 0
    
    let favoriteLinesService = FavoriteLinesService.shared

    private enum PersistenceKey {
        static let selectedLines = "liveMap.selectedLines"
        static let selectedVehicleType = "liveMap.selectedVehicleType"
    }

    private static let lyonCenter = CLLocationCoordinate2D(latitude: 45.764043, longitude: 4.835659)
    private static let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    
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
        
        if let saved = UserDefaults.standard.array(forKey: PersistenceKey.selectedLines) as? [String] {
            _selectedLines = Published(initialValue: Set(saved))
        }
        if let raw = UserDefaults.standard.string(forKey: PersistenceKey.selectedVehicleType) {
            _selectedVehicleType = Published(initialValue: VehicleType(rawValue: raw))
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
        result = result.visibleIn(region: visibleRegion, buffer: .standard, coordinateProvider: { $0.coordinate })
        
        filteredVehicles = result
    }
    
    var displayVehicles: [Vehicle] { filteredVehicles }
    
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
        consecutiveErrors = 0
        defer { isLoading = false }
        
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
                consecutiveErrors = 0
                
                // Mettre à jour les véhicules filtrés et clusters
                updateFilteredVehicles()
                return
            } catch let siriError as ServiceError {
                lastError = siriError
                AppLogger.debug("⚠️ Erreur SIRI tentative \(attempt)/\(attempts): \(siriError.errorDescription ?? "inconnue")")
            } catch is CancellationError {
                AppLogger.debug("⏹️ Chargement véhicules annulé")
                return
            } catch let urlError as URLError where urlError.code == .cancelled {
                AppLogger.debug("⏹️ Requête véhicules annulée (URLError.cancelled)")
                return
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
        if let siriError = lastError as? ServiceError {
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
                existing.updateTarget(vehicle: vehicle, duration: 5.0, currentTime: now, reduceMotion: reduceMotion)
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
            // Ne pas ajouter un ghost si un véhicule du même trip (même ligne,
            // même type, < 100 m) est déjà présent dans fetched — c'est le même
            // bus physique qui a changé d'identifiant de trip au terminus.
            .filter { ghost in
                !fetched.contains { newV in
                    newV.lineName == ghost.lineName &&
                    newV.vehicleType == ghost.vehicleType &&
                    fastDistance2D(ghost.coordinate, newV.coordinate) < 100
                }
            }
        return fetched + graceVehicles
    }

    @inline(__always)
    private func fastDistance2D(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let dlat = (b.latitude  - a.latitude)  * 111_320
        let dlon = (b.longitude - a.longitude) * 111_320 * cos(a.latitude * .pi / 180)
        return (dlat * dlat + dlon * dlon).squareRoot()
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
        error = nil
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

    /// Appelé au retour en foreground : force un fetch immédiat
    /// puis s'assure que le stream tourne.
    /// Fonctionne que le stream ait été arrêté (background long) ou non (inactive court).
    func resumeFromForeground() {
        // Redémarrer le stream : startLiveStream débute toujours par un fetch
        stopLiveStream()
        startLiveStream()
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
        } catch {
            consecutiveErrors += 1
            // Only surface error after 3 consecutive failures (transient tolerance)
            if consecutiveErrors >= 3 {
                self.error = (error as? ServiceError)?.errorDescription ?? error.localizedDescription
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
        }
    }
    
    func toggleLineSelection(_ line: String) {
        if selectedLines.contains(line) {
            selectedLines.remove(line)
        } else {
            selectedLines.insert(line)
        }
        updateFilteredVehicles()
    }
    
    func clearFilters() {
        selectedVehicleType = nil
        selectedLine = nil
        selectedLines.removeAll()
        updateFilteredVehicles()
    }
    
    deinit {
        streamTask?.cancel()
    }
}
