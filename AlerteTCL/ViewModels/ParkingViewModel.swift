import Foundation
import SwiftUI
import MapKit
import Combine
import Shared

@MainActor
final class ParkingViewModel: ObservableObject {
    @Published var parkings: [Parking] = []
    @Published var parcRelais: [Parking] = []
    @Published var showRealtimeParkings: Bool = true {
        didSet {
            if oldValue != showRealtimeParkings {
                updateClustersIfNeeded(force: true)
            }
        }
    }
    @Published var showParcRelais: Bool = true
    /// Stations Vélo'v (type « Vélo'v » seulement), rechargées toutes les minutes comme les parkings voiture.
    @Published private(set) var velovStations: [VelovStation] = []
    /// Ce que les marqueurs Vélo'v comptent : tous les vélos, une motorisation, ou les places libres.
    /// Le choix est conservé entre deux lancements.
    @Published private(set) var velovFilter: VelovFilter = VelovFilter.companion.fromName(
        name: UserDefaults.standard.string(forKey: ParkingViewModel.velovFilterKey)
    )
    private static let velovFilterKey = "parking.velovFilter"
    /// Heure où `velovStations` a été relevé (epoch, ms) : le départ des prévisions, le même pour la
    /// carte et pour la fiche d'une station.
    @Published private(set) var velovOriginEpochMs: Int64 = 0
    /// Vrai quand une prévision existe pour le relevé courant : la carte montre alors son curseur d'heure.
    @Published private(set) var velovForecastAvailable = false
    /// Échéance du curseur d'heure de la carte : 0 pour « Maintenant », puis une par quart d'heure.
    @Published private(set) var velovForecastStep: Int32 = 0
    /// Marqueurs prévus à l'échéance du curseur. Nil à « Maintenant », et tant que la première prévision
    /// demandée n'est pas arrivée : la carte dessine alors l'état réel.
    @Published private var velovForecastMarkers: [VelovMapMarker]?
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastUpdate: Date?
    @Published var isViewActive = false
    @Published var currentZoomLevel: Double = 0.15
    @Published var visibleRegion: MKCoordinateRegion?
    @Published var isLoadingInBackground = false
    
    // Debounce pour éviter trop de requêtes lors du pan/zoom
    private var regionUpdateTask: Task<Void, Never>?
    private let regionUpdateDebounce: UInt64 = 300_000_000 // 300ms
    
    @Published var selectedParkingType: ParkingType = .car {
        didSet {
            if oldValue != selectedParkingType {
                // 1. Vider immédiatement l'affichage pour feedback instantané
                parkings = []
                velovStations = []
                velovForecastAvailable = false
                velovForecastStep = 0
                velovForecastMarkers = nil
                invalidateClusterCache()
                error = nil
                
                // 2. Annuler tout chargement en cours
                currentLoadTask?.cancel()
                regionUpdateTask?.cancel()
                
                // 3. Gérer l'auto-refresh (voitures et Vélo'v : disponibilité en direct)
                stopAutoRefresh()
                startAutoRefresh()
                
                // 4. Charger les nouvelles données (cache-first, viewport-first)
                currentLoadTask = Task { [weak self] in
                    guard let self, !Task.isCancelled else { return }
                    if self.selectedParkingType == .velov {
                        await self.loadVelovStations()
                        return
                    }
                    
                    // Si on a un cache, l'afficher immédiatement
                    if let cached = self.parkingsCache[self.selectedParkingType], !cached.isEmpty {
                        self.parkings = cached
                        self.updateClustersIfNeeded(force: true)
                        
                        // Puis rafraîchir en arrière-plan pour voitures (temps réel)
                        if self.selectedParkingType == .car {
                            await self.loadParkings()
                        }
                    } else {
                        // Pas de cache : viewport-first pour vélos/2-roues, tout pour voitures
                        if self.selectedParkingType == .car {
                            await self.loadParkings()
                        } else {
                            await self.loadParkingsProgressively()
                        }
                    }
                }
            }
        }
    }
    
    private var currentLoadTask: Task<Void, Never>?

    init(type: ParkingType = .car) {
        selectedParkingType = type
    }
    
    // Cache par type pour éviter de recharger
    private var parkingsCache: [ParkingType: [Parking]] = [:]
    
    @Published var mapRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 45.764043, longitude: 4.835659),
        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    )
    
    private var refreshTask: Task<Void, Never>?
    private let refreshInterval: TimeInterval = 60
    
    private let clusteringConfig: ClusteringEngine.Configuration = .default

    var totalPlacesDisponibles: Int {
        parkings.reduce(0) { $0 + $1.placesDisponibles }
    }
    
    var totalCapacite: Int {
        parkings.reduce(0) { $0 + $1.capaciteTotale }
    }
    
    var parkingsOuverts: Int {
        parkings.filter { $0.etat == .ouvert }.count
    }
    
    var parkingsAvecPlaces: Int {
        parkings.filter { $0.placesDisponibles > 0 && $0.etat == .ouvert }.count
    }
    
    // MARK: - Viewport Filtering
    
    /// Parkings visibles dans la région actuelle (avec buffer)
    /// Note: Si aucune région n'est définie, retourne tous les parkings
    var visibleParkings: [Parking] {
        guard visibleRegion != nil else { return parkings }
        // Buffer plus large pour les vélos pour améliorer les performances
        let bufferConfig: ViewportFilter.BufferConfig = selectedParkingType == .bike ? .large : .standard
        return parkings.visibleIn(region: visibleRegion, buffer: bufferConfig)
    }
    
    // MARK: - Clustering

    @Published private(set) var displayClusters: [MapCluster<Parking>] = []
    @Published private(set) var displayParkings: [Parking] = []
    private var lastClusteringZoom: Double = 0
    private var lastClusteringParkingCount: Int = 0

    /// Clustering actif dès que ≥ 50 points visibles (vélo/2-roues), ou selon le zoom (voitures).
    private var shouldCluster: Bool {
        if selectedParkingType == .bike || selectedParkingType == .motorized2Wheel {
            return visibleParkings.count >= 50
        }
        return ClusteringEngine.shouldCluster(zoomLevel: currentZoomLevel, config: clusteringConfig)
    }

    private func updateClustersIfNeeded(force: Bool = false) {
        let zoomChanged = abs(currentZoomLevel - lastClusteringZoom) > 0.003
        let countChanged = visibleParkings.count != lastClusteringParkingCount
        guard force || zoomChanged || countChanged else { return }

        // Appliquer le filtre temps réel avant le clustering
        let visible: [Parking]
        if selectedParkingType == .car && !showRealtimeParkings {
            // Masquer les parkings voiture (laisser seulement les P+R via showParcRelais)
            visible = []
        } else {
            visible = visibleParkings
        }
        lastClusteringZoom = currentZoomLevel
        lastClusteringParkingCount = visible.count

        if shouldCluster {
            let result = ClusteringEngine.createClusters(from: visible, zoomLevel: currentZoomLevel, config: clusteringConfig)
            displayClusters = result.clusters
            displayParkings = result.unclustered
        } else {
            displayClusters = []
            // Plafond à 500 markers individuels pour ne pas saturer MapKit
            displayParkings = visible.count <= 500 ? visible : Array(visible.prefix(500))
        }
    }

    private func invalidateClusterCache() {
        displayClusters = []
        displayParkings = []
        lastClusteringZoom = -1
        lastClusteringParkingCount = -1
    }
    
    func updateZoomLevel(_ span: MKCoordinateSpan) {
        currentZoomLevel = span.latitudeDelta
        updateClustersIfNeeded()
    }
    
    func updateVisibleRegion(_ region: MKCoordinateRegion) {
        let previousRegion = visibleRegion
        visibleRegion = region
        updateClustersIfNeeded()
        
        // Pour vélos/2-roues: charger les données spatiales avec debounce
        if selectedParkingType == .bike || selectedParkingType == .motorized2Wheel {
            // Vérifier si la région a significativement changé
            let significantChange = previousRegion == nil || 
                abs(region.center.latitude - (previousRegion?.center.latitude ?? 0)) > 0.005 ||
                abs(region.center.longitude - (previousRegion?.center.longitude ?? 0)) > 0.005
            
            if significantChange {
                scheduleRegionLoad(region)
            }
        }
    }
    
    /// Planifie un chargement de données avec debounce
    private func scheduleRegionLoad(_ region: MKCoordinateRegion) {
        regionUpdateTask?.cancel()
        regionUpdateTask = Task { [weak self] in
            // Attendre le debounce
            try? await Task.sleep(nanoseconds: self?.regionUpdateDebounce ?? 300_000_000)
            guard !Task.isCancelled else { return }
            await self?.loadParkingsInRegion(region)
        }
    }
    
    func loadParkings() async {
        guard !isLoading else { return }
        guard !Task.isCancelled else { return }
        
        AppLogger.debug("🔄 ParkingViewModel: Début du chargement (\(selectedParkingType.rawValue))...")
        let type = selectedParkingType
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let fetchedParkings = try await ParkingService.shared.fetchParkings(type: type)
            // Si la tâche a été annulée ou le type a changé pendant le fetch, ignorer
            guard !Task.isCancelled, type == selectedParkingType else { return }
            parkings = fetchedParkings.sorted { $0.nom < $1.nom }
            lastUpdate = Date()

            // Mettre en cache
            parkingsCache[type] = parkings
            
            // Forcer la mise à jour des clusters
            updateClustersIfNeeded(force: true)
            
            AppLogger.debug("✅ ParkingViewModel: \(parkings.count) parkings \(selectedParkingType.rawValue) chargés avec succès")
            AppLogger.debug("📊 ParkingViewModel: Total places: \(totalPlacesDisponibles)/\(totalCapacite)")
            AppLogger.debug("🅿️ ParkingViewModel: Parkings ouverts: \(parkingsOuverts)")
            
        } catch {
            AppLogger.debug("⚠️ Erreur parkings (non-bloquante): \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
    }
    
    /// Chargement spatial pour vélos et 2-roues (charge uniquement la zone visible)
    func loadParkingsInRegion(_ region: MKCoordinateRegion) async {
        guard !isLoadingInBackground, !Task.isCancelled else { return }
        
        isLoadingInBackground = true
        error = nil
        
        defer {
            isLoadingInBackground = false
        }
        
        do {
            let fetchedParkings = try await ParkingService.shared.fetchParkingsInRegion(
                type: selectedParkingType,
                region: region
            )
            
            // Si la tâche a été annulée pendant le fetch (changement d'onglet), ignorer
            guard !Task.isCancelled else { return }
            
            // Fusionner avec les parkings existants (garder les nouveaux + ceux déjà chargés)
            var mergedParkings = parkings
            let existingIds = Set(parkings.map { $0.id })
            
            for parking in fetchedParkings {
                if !existingIds.contains(parking.id) {
                    mergedParkings.append(parking)
                }
            }
            
            parkings = mergedParkings  // pas de sort : le tri est inutile pour l'affichage carte
            parkingsCache[selectedParkingType] = parkings
            lastUpdate = Date()
            
            updateClustersIfNeeded(force: true)
            
            AppLogger.debug("✅ ParkingViewModel: \(fetchedParkings.count) parkings \(selectedParkingType.rawValue) chargés (total: \(parkings.count))")
            
        } catch {
            AppLogger.debug("⚠️ Erreur chargement spatial: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
    }
    
    /// Chargement initial pour vélos/2-roues basé sur la région courante
    func loadParkingsProgressively() async {
        // Utiliser la région visible ou la région par défaut
        let region = visibleRegion ?? mapRegion
        await loadParkingsInRegion(region)
    }

    /// Stations Vélo'v avec leur disponibilité (relais, cache d'une minute côté module partagé).
    func loadVelovStations() async {
        guard !Task.isCancelled else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        // Premier affichage des stations : le modèle de prévision se charge pendant qu'elles arrivent.
        if velovStations.isEmpty { VelovForecastService.companion.shared.warmUp() }
        do {
            let stations = try await VelovService.companion.shared.fetchStations(forceRefresh: false)
            guard !Task.isCancelled, selectedParkingType == .velov else { return }
            // Le tableau est gardé tel que le module partagé l'a rendu : c'est lui que la prévision reçoit.
            velovStations = stations
            let now = Date()
            velovOriginEpochMs = Int64(now.timeIntervalSince1970 * 1000)
            lastUpdate = now
            await refreshVelovForecast()
        } catch {
            AppLogger.debug("⚠️ Stations Vélo'v indisponibles : \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
    }

    /// Ce que la carte dessine dans la région visible, comme les parkings : l'état réel de chaque
    /// station, ou sa prévision quand le curseur d'heure a quitté « Maintenant ».
    var visibleVelovMarkers: [VelovMapMarker] {
        let markers = velovForecastMarkers ?? velovStations.map { VelovMapMarker(station: $0, filter: velovFilter) }
        guard let region = visibleRegion else { return markers }
        let minLat = region.center.latitude - region.span.latitudeDelta
        let maxLat = region.center.latitude + region.span.latitudeDelta
        let minLon = region.center.longitude - region.span.longitudeDelta
        let maxLon = region.center.longitude + region.span.longitudeDelta
        return markers.filter { $0.station.lat >= minLat && $0.station.lat <= maxLat && $0.station.lng >= minLon && $0.station.lng <= maxLon }
    }

    /// La station `id` dans le dernier relevé : une fiche ouverte suit ainsi les rafraîchissements.
    func velovStation(id: Int32) -> VelovStation? {
        velovStations.first { $0.id == id }
    }

    /// Voitures et Vélo'v ont une disponibilité en direct, rechargée toutes les minutes.
    var hasLiveData: Bool { selectedParkingType == .car || selectedParkingType == .velov }

    /// Change ce que les marqueurs Vélo'v comptent, et retient le choix.
    func selectVelovFilter(_ filter: VelovFilter) {
        guard filter != velovFilter else { return }
        velovFilter = filter
        UserDefaults.standard.set(filter.name, forKey: Self.velovFilterKey)
        refreshVelovForecastMarkers()
    }

    // MARK: - Prévision Vélo'v

    /// Déplace le curseur d'heure de la carte. À « Maintenant », la carte reprend aussitôt l'état réel ;
    /// au-delà, elle garde ce qu'elle montre jusqu'à l'arrivée de la prévision demandée.
    func selectVelovForecastStep(_ step: Int32) {
        guard step != velovForecastStep else { return }
        velovForecastStep = step
        refreshVelovForecastMarkers()
    }

    /// La prévision de `station` pour sa fiche, sur le relevé et l'heure de départ de la carte ; nil
    /// quand il n'y a rien à montrer (pas de prévision, station fermée ou inconnue du modèle).
    func velovForecastSheet(for station: VelovStation) async -> VelovForecastSheet? {
        try? await VelovForecastService.companion.shared.sheet(station: station, stations: velovStations, originEpochMs: velovOriginEpochMs)
    }

    /// À chaque relevé des stations (toutes les minutes) : la prévision est-elle encore disponible ?
    /// Le curseur garde son échéance, qui part désormais du nouveau relevé (l'heure visée avance d'une
    /// minute), et la carte ce qu'elle montre jusqu'à l'arrivée des marqueurs recalculés. Si la prévision
    /// n'est plus disponible, le curseur disparaît et la carte revient à l'état réel.
    private func refreshVelovForecast() async {
        let origin = velovOriginEpochMs
        let available = (try? await VelovForecastService.companion.shared.isAvailable(originEpochMs: origin))?.boolValue ?? false
        guard origin == velovOriginEpochMs, selectedParkingType == .velov else { return }
        velovForecastAvailable = available
        if !available { velovForecastStep = 0 }
        refreshVelovForecastMarkers()
    }

    /// Demande les marqueurs de l'échéance, du relevé et du filtre courants. Annuler une tâche Swift
    /// n'arrête pas le calcul Kotlin : une réponse nulle (demande dépassée par une plus récente) ou
    /// arrivée après un changement d'échéance, de relevé ou de filtre est ignorée.
    private func refreshVelovForecastMarkers() {
        let step = velovForecastStep
        guard step > 0 else {
            velovForecastMarkers = nil
            return
        }
        let stations = velovStations
        let origin = velovOriginEpochMs
        let filter = velovFilter
        Task { [weak self] in
            let markers = try? await VelovForecastService.companion.shared.markers(stations: stations, originEpochMs: origin, step: step, filter: filter)
            guard let self, let markers,
                  step == self.velovForecastStep, origin == self.velovOriginEpochMs, filter == self.velovFilter else { return }
            self.velovForecastMarkers = markers.map { VelovMapMarker(forecast: $0, filter: filter) }
        }
    }

    /// Recharge le type courant quand il a des données en direct.
    func refreshLiveData() async {
        switch selectedParkingType {
        case .car: await loadParkings()
        case .velov: await loadVelovStations()
        case .bike, .motorized2Wheel: break
        }
    }
    
    func startAutoRefresh() {
        stopAutoRefresh()
        
        guard hasLiveData else {
            AppLogger.debug("⏸️ ParkingViewModel: Pas de refresh auto pour \(selectedParkingType.rawValue) (données statiques)")
            return
        }
        
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                guard self.isViewActive else { return }
                try? await Task.sleep(nanoseconds: UInt64(self.refreshInterval * 1_000_000_000))
                guard !Task.isCancelled, self.isViewActive else { return }
                await self.refreshLiveData()
            }
        }

    }
    
    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
    
    func onAppear() {
        isViewActive = true
        currentLoadTask?.cancel()
        currentLoadTask = Task(priority: .userInitiated) { [weak self] in
            guard let self = self, !Task.isCancelled else { return }
            
            // Restaurer depuis le cache immédiatement si disponible
            if let cached = self.parkingsCache[self.selectedParkingType], !cached.isEmpty, self.parkings.isEmpty {
                self.parkings = cached
                self.updateClustersIfNeeded(force: true)
            }
            
            // Charger les P+R en parallèle
            async let prLoad: Void = self.loadParcRelais()

            // Voitures et Vélo'v : toujours recharger (temps réel).
            // Vélos/2-roues : charger via updateVisibleRegion.
            if self.hasLiveData {
                await self.refreshLiveData()
            } else if self.parkings.isEmpty {
                await self.loadParkingsProgressively()
            }
            _ = await prLoad
            self.startAutoRefresh()
        }
    }

    func loadParcRelais(forceRefresh: Bool = false) async {
        do {
            parcRelais = try await ParcRelaisService.shared.fetchParcRelais(forceRefresh: forceRefresh)
        } catch {
            AppLogger.debug("⚠️ ParcRelais: \(error.localizedDescription)")
        }
    }

    /// P+R affichables : exclut ceux déjà présents dans le dataset parkings standard
    /// (dédup recalculée à chaque lecture — insensible à l'ordre d'arrivée des fetchs)
    var visibleParcRelais: [Parking] {
        let existingNoms = Set(parkings.map { $0.nom.lowercased().trimmingCharacters(in: .whitespaces) })
        return parcRelais.filter { !existingNoms.contains($0.nom.lowercased().trimmingCharacters(in: .whitespaces)) }
    }
    
    func onDisappear() {
        isViewActive = false
        stopAutoRefresh()
        currentLoadTask?.cancel()
        currentLoadTask = nil
        regionUpdateTask?.cancel()
        regionUpdateTask = nil
    }
}
