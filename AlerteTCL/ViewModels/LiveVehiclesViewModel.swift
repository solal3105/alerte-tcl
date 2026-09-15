import Foundation
import SwiftUI
import Combine
import CoreLocation
import MapKit
import Shared

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
    /// Filtre « bus de cet arrêt » (ligne + sens) choisi depuis la fiche d'un arrêt.
    /// Volontairement non persisté : il disparaît à la fermeture de l'application.
    @Published private(set) var stopFocus: StopLineFocus? {
        didSet { updateFilteredVehicles() }
    }
    @Published var showBusTraces = false {
        didSet { UserDefaults.standard.set(showBusTraces, forKey: PersistenceKey.showBusTraces) }
    }
    @Published var showTramTraces = true {
        didSet { UserDefaults.standard.set(showTramTraces, forKey: PersistenceKey.showTramTraces) }
    }
    @Published var showMetroTraces = true {
        didSet { UserDefaults.standard.set(showMetroTraces, forKey: PersistenceKey.showMetroTraces) }
    }
    /// Non-@Published : lu par les moteurs de clustering/viewport mais pas par
    /// les Views SwiftUI (la carte est en UIKit). Publier ces deux propriétés
    /// invaliderait le body de `LiveMapView` à chaque mouvement de caméra
    /// (~60 Hz en glissement) et relancerait `updateUIView`.
    var currentZoomLevel: Double = 0.15
    var visibleRegion: MKCoordinateRegion?
    @Published var isInitialLoadComplete = false
    @Published var isLive = false
    /// Incrémenté quand la palette officielle des couleurs de lignes change : la carte
    /// régénère alors ses images de véhicules, d'arrêts et de tracés.
    @Published private(set) var paletteVersion = 0
    
    // Cached computed properties for performance
    // `filteredVehicles` est un état interne : les vues lisent `displayVehicles`.
    // Inutile de déclencher une seconde publication par fetch.
    private(set) var filteredVehicles: [Vehicle] = []
    
    private var streamTask: Task<Void, Never>?
    private var regionUpdateTask: Task<Void, Never>?
    private var consecutiveErrors = 0
    /// L'API SIRI Lite TCL publie de nouvelles positions toutes les ~15 s.
    /// On fetch à 15 s pour aligner avec le TTL du cache Cloudflare (15 s) :
    /// chaque requête retourne des données fraîches. Grand Lyon reçoit ≤ 1 req/15 s.
    private let baseInterval: TimeInterval = 15
    private let maxInterval: TimeInterval = 60
    private var isFirstLoad = true
    
    private var cachedAvailableLines: [String] = []
    private var lastLineNames: Set<String> = []
    
    let favoriteLinesService = FavoriteLinesService.shared

    private enum PersistenceKey {
        static let selectedLines = "liveMap.selectedLines"
        static let selectedVehicleType = "liveMap.selectedVehicleType"
        static let showBusTraces = "liveMap.showBusTraces"
        static let showTramTraces = "liveMap.showTramTraces"
        static let showMetroTraces = "liveMap.showMetroTraces"
    }

    init() {
        if let saved = UserDefaults.standard.array(forKey: PersistenceKey.selectedLines) as? [String] {
            _selectedLines = Published(initialValue: Set(saved))
        }
        if let raw = UserDefaults.standard.string(forKey: PersistenceKey.selectedVehicleType) {
            _selectedVehicleType = Published(initialValue: VehicleType(rawValue: raw))
        }
        if UserDefaults.standard.object(forKey: PersistenceKey.showBusTraces) != nil {
            _showBusTraces = Published(initialValue: UserDefaults.standard.bool(forKey: PersistenceKey.showBusTraces))
        }
        if UserDefaults.standard.object(forKey: PersistenceKey.showTramTraces) != nil {
            _showTramTraces = Published(initialValue: UserDefaults.standard.bool(forKey: PersistenceKey.showTramTraces))
        }
        if UserDefaults.standard.object(forKey: PersistenceKey.showMetroTraces) != nil {
            _showMetroTraces = Published(initialValue: UserDefaults.standard.bool(forKey: PersistenceKey.showMetroTraces))
        }
        // La persistance de la palette est branchée au démarrage de l'app ; on y ajoute le
        // rafraîchissement de la carte sans écraser cette persistance.
        let persist = LinePalette.shared.onChange
        LinePalette.shared.onChange = { [weak self] encoded in
            persist?(encoded)
            Task { @MainActor in self?.paletteVersion += 1 }
        }
    }

    /// Charge l'index des fiches horaires, qui porte la palette officielle des couleurs de lignes.
    func loadLinePalette() async {
        do {
            _ = try await TimetableService.companion.shared.fetchIndex()
        } catch {
            AppLogger.debug("⚠️ Palette des lignes indisponible : \(error.localizedDescription)")
        }
    }
    
    private func updateFilteredVehicles() {
        var result = vehicles
        
        if let focus = stopFocus {
            // Le filtre d'arrêt prime sur les autres : on veut voir ces bus, quels que soient les réglages.
            result = result.filter { focus.matches(lineName: $0.lineName, vehicleDirection: $0.direction) }
        } else {
            if let type = selectedVehicleType {
                result = result.filter { $0.vehicleType == type }
            }
            
            if let line = selectedLine, !line.isEmpty {
                result = result.filter { $0.lineName == line }
            } else if !selectedLines.isEmpty {
                result = result.filter { selectedLines.contains($0.lineName) }
            }
        }
        
        // Filtrage viewport avec buffer standard
        result = result.visibleIn(region: visibleRegion, buffer: .standard, coordinateProvider: { $0.coordinate })
        
        filteredVehicles = result
    }
    
    /// Relu à chaque synchronisation de la carte : un véhicule peut franchir le délai
    /// d'obsolescence entre deux fetchs, il ne doit alors plus être redessiné.
    var displayVehicles: [Vehicle] { filteredVehicles.filter(\.isShownOnMap) }
    
    var availableLines: [String] {
        let currentLineNames = Set(vehicles.map { $0.lineName })
        if currentLineNames != lastLineNames {
            cachedAvailableLines = computeAvailableLines()
            lastLineNames = currentLineNames
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
        } catch {
            AppLogger.debug("❌ Erreur chargement lignes de bus: \(error)")
        }
    }
    
    func loadTransitLines() async {
        do {
            transitLines = try await TransitLineService.shared.fetchTransitLines()
            AppLogger.debug("✅ ViewModel: \(transitLines.count) lignes de transport chargées")
        } catch {
            AppLogger.debug("❌ Erreur chargement lignes de transport: \(error)")
        }
    }
    
    func loadVehicles() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil
        consecutiveErrors = 0
        defer { isLoading = false }

        // Retry automatique réservé au premier chargement
        let result = await withInitialRetry(attempts: isInitialLoadComplete ? 1 : 2) {
            try await SIRILiteService.shared.fetchVehiclePositions()
        }

        // nil = annulation (vue quittée pendant le chargement) : rien à afficher
        guard let result else { return }

        switch result {
        case .success(let fetchedVehicles):
            applyFetchedVehicles(fetchedVehicles)
            isInitialLoadComplete = true
        case .failure(let lastError):
            // Toutes les tentatives ont échoué
            self.error = (lastError as? ServiceError)?.errorDescription ?? lastError.localizedDescription
        }
    }

    /// Applique un lot de véhicules fraîchement récupéré (état, animation, filtrage).
    private func applyFetchedVehicles(_ fetched: [Vehicle]) {
        updateAnimatedVehicles(with: fetched)
        // Les véhicules dont TCL n'a pas retransmis la position depuis `Vehicle.hideAfterSeconds` quittent la carte.
        vehicles = mergeWithGracePeriodVehicles(fetched).filter(\.isShownOnMap)
        lastUpdate = Date()
        error = nil
        consecutiveErrors = 0
        updateFilteredVehicles()
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
    
    /// Intervalle effectif du stream temps réel (backoff progressif sur erreurs) — lu par le badge LIVE.
    var adaptiveInterval: TimeInterval {
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
            applyFetchedVehicles(fetched)
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
    
    func focusOnStop(_ focus: StopLineFocus) {
        stopFocus = focus
    }

    func clearStopFocus() {
        stopFocus = nil
    }

    /// Nombre de véhicules concernés par le filtre d'arrêt, hors limitation à l'écran.
    var stopFocusVehicleCount: Int {
        guard let focus = stopFocus else { return 0 }
        return vehicles.filter { focus.matches(lineName: $0.lineName, vehicleDirection: $0.direction) }.count
    }

    /// Cadre l'arrêt et les véhicules concernés par le filtre d'arrêt (nil sans filtre).
    func stopFocusRegion() -> MKCoordinateRegion? {
        guard let focus = stopFocus else { return nil }
        var coordinates = vehicles
            .filter { focus.matches(lineName: $0.lineName, vehicleDirection: $0.direction) }
            .map(\.coordinate)
        coordinates.append(CLLocationCoordinate2D(latitude: focus.latitude, longitude: focus.longitude))
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        guard let minLat = latitudes.min(), let maxLat = latitudes.max(),
              let minLon = longitudes.min(), let maxLon = longitudes.max() else { return nil }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        // Marge autour des points, et un cadre minimal quand tout est concentré près de l'arrêt.
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.012),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.012)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    func clearFilters() {
        stopFocus = nil
        selectedVehicleType = nil
        selectedLine = nil
        selectedLines.removeAll()
        showBusTraces = false
        showTramTraces = true
        showMetroTraces = true
        updateFilteredVehicles()
    }
    
    deinit {
        streamTask?.cancel()
    }
}
