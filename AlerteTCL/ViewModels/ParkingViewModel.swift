import Foundation
import MapKit
import Combine

@MainActor
final class ParkingViewModel: ObservableObject {
    @Published var parkings: [Parking] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastUpdate: Date?
    @Published var secondsUntilNextRefresh: Int = 60
    @Published var refreshProgress: Double = 0.0
    @Published var isViewActive = false
    @Published var currentZoomLevel: Double = 0.15
    @Published var visibleRegion: MKCoordinateRegion?
    
    // État de chargement progressif (non-bloquant)
    @Published var loadingMessage: String = ""
    @Published var loadingProgress: Double = 0.0
    @Published var isLoadingInBackground = false
    @Published var loadedCount: Int = 0
    @Published var totalToLoad: Int = 0
    
    @Published var selectedParkingType: ParkingType = .car {
        didSet {
            if oldValue != selectedParkingType {
                // Invalider le cache de clustering pour forcer le recalcul
                invalidateClusterCache()
                // Pour les vélos/2-roues, charger seulement si pas déjà en cache
                if selectedParkingType == .bike && !bikeParkingsLoaded {
                    Task {
                        await loadParkingsProgressively()
                    }
                } else if selectedParkingType == .motorized2Wheel && !moto2WheelParkingsLoaded {
                    Task {
                        await loadParkingsProgressively()
                    }
                } else if selectedParkingType == .car {
                    Task {
                        await loadParkings()
                    }
                } else {
                    // Déjà chargés, juste mettre à jour les clusters
                    updateClustersIfNeeded(force: true)
                }
            }
        }
    }
    
    private var bikeParkingsLoaded = false
    private var moto2WheelParkingsLoaded = false
    
    // Cache par type pour éviter de recharger
    private var parkingsCache: [ParkingType: [Parking]] = [:]
    
    @Published var mapRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 45.764043, longitude: 4.835659),
        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    )
    
    private var refreshTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?
    private let refreshInterval: TimeInterval = 60
    
    // Configuration de clustering - désactivé pour vélos/2-roues sauf zoom très dézoomé
    private var clusteringConfig: ClusteringEngine.Configuration {
        .default
    }
    
    /// Seuil de zoom pour activer le clustering des vélos/2-roues (très dézoomé)
    /// 0.05 = vue très large de Lyon, clustering activé seulement à ce niveau (divisé par 2 pour apparaître plus tard au dézoom)
    private let bikeClusteringZoomThreshold: Double = 0.03
    
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
    
    @Published private(set) var cachedClusters: [MapCluster<Parking>] = []
    @Published private(set) var cachedUnclusteredParkings: [Parking] = []
    private var lastClusteringZoom: Double = 0
    private var lastClusteringParkingCount: Int = 0
    
    var shouldShowClusters: Bool {
        // Pour vélos et 2-roues: clustering seulement si très dézoomé
        if selectedParkingType == .bike || selectedParkingType == .motorized2Wheel {
            return currentZoomLevel >= bikeClusteringZoomThreshold
        }
        // Pour voitures: clustering normal
        return ClusteringEngine.shouldCluster(zoomLevel: currentZoomLevel, config: clusteringConfig)
    }
    
    private func updateClustersIfNeeded(force: Bool = false) {
        let zoomChanged = abs(currentZoomLevel - lastClusteringZoom) > 0.003
        let parkingsChanged = visibleParkings.count != lastClusteringParkingCount
        
        guard force || zoomChanged || parkingsChanged else { return }
        
        let parkingsToCluster = visibleParkings
        
        // Pour vélos/2-roues: pas de clustering sauf si très dézoomé
        if (selectedParkingType == .bike || selectedParkingType == .motorized2Wheel) && !shouldShowClusters {
            cachedClusters = []
            cachedUnclusteredParkings = parkingsToCluster
            lastClusteringZoom = currentZoomLevel
            lastClusteringParkingCount = parkingsToCluster.count
            print("🚲 Pas de clustering pour \(selectedParkingType.rawValue): \(parkingsToCluster.count) parkings affichés")
            return
        }
        
        print("🔄 Clustering: \(parkingsToCluster.count) parkings, zoom: \(currentZoomLevel)")
        
        let result = ClusteringEngine.createClusters(from: parkingsToCluster, zoomLevel: currentZoomLevel, config: clusteringConfig)
        cachedClusters = result.clusters
        cachedUnclusteredParkings = result.unclustered
        lastClusteringZoom = currentZoomLevel
        lastClusteringParkingCount = parkingsToCluster.count
        
        print("📊 Clusters: \(cachedClusters.count), Unclustered: \(cachedUnclusteredParkings.count)")
    }
    
    private func invalidateClusterCache() {
        cachedClusters = []
        cachedUnclusteredParkings = []
        lastClusteringZoom = -1  // Force recalculation
        lastClusteringParkingCount = -1
    }
    
    var clusters: [MapCluster<Parking>] {
        cachedClusters
    }
    
    var unclusteredParkings: [Parking] {
        cachedUnclusteredParkings
    }
    
    // MARK: - Display Limits
    
    private let maxDisplayMarkers = 1000
    
    var shouldShowTooManyMarkersWarning: Bool {
        // Compter TOUS les parkings visibles (pas les markers)
        return visibleParkings.count > maxDisplayMarkers
    }
    
    var displayClusters: [MapCluster<Parking>] {
        guard !shouldShowTooManyMarkersWarning else { return [] }
        return clusters
    }
    
    var displayParkings: [Parking] {
        guard !shouldShowTooManyMarkersWarning else { return [] }
        return unclusteredParkings
    }
    
    func updateZoomLevel(_ span: MKCoordinateSpan) {
        currentZoomLevel = span.latitudeDelta
        updateClustersIfNeeded()
    }
    
    func updateVisibleRegion(_ region: MKCoordinateRegion) {
        visibleRegion = region
        updateClustersIfNeeded()
    }
    
    func loadParkings() async {
        guard !isLoading else { return }
        
        print("🔄 ParkingViewModel: Début du chargement (\(selectedParkingType.rawValue))...")
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let fetchedParkings = try await ParkingService.shared.fetchParkings(type: selectedParkingType)
            parkings = fetchedParkings.sorted { $0.nom < $1.nom }
            lastUpdate = Date()
            secondsUntilNextRefresh = Int(refreshInterval)
            
            // Mettre en cache
            parkingsCache[selectedParkingType] = parkings
            
            // Marquer comme chargé selon le type
            switch selectedParkingType {
            case .bike:
                bikeParkingsLoaded = true
            case .motorized2Wheel:
                moto2WheelParkingsLoaded = true
            case .car:
                break
            }
            
            // Forcer la mise à jour des clusters
            updateClustersIfNeeded(force: true)
            
            print("✅ ParkingViewModel: \(parkings.count) parkings \(selectedParkingType.rawValue) chargés avec succès")
            print("📊 ParkingViewModel: Total places: \(totalPlacesDisponibles)/\(totalCapacite)")
            print("🅿️ ParkingViewModel: Parkings ouverts: \(parkingsOuverts)")
            
        } catch {
            print("⚠️ Erreur parkings (non-bloquante): \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
    }
    
    /// Chargement progressif pour vélos et 2-roues (affichage au fur et à mesure)
    func loadParkingsProgressively() async {
        // Vérifier si déjà en cache
        if let cached = parkingsCache[selectedParkingType], !cached.isEmpty {
            parkings = cached
            updateClustersIfNeeded(force: true)
            print("✨ ParkingViewModel: Utilisation du cache pour \(selectedParkingType.rawValue)")
            return
        }
        
        guard !isLoadingInBackground else { return }
        
        isLoadingInBackground = true
        defer {
            isLoadingInBackground = false
            loadingProgress = 0.0
        }
        
        loadingMessage = "Chargement des \(selectedParkingType == .bike ? "parkings vélos" : "parkings 2-roues")..."
        loadingProgress = 0.0
        loadedCount = 0
        error = nil
        
        print("🔄 ParkingViewModel: Début du chargement progressif (\(selectedParkingType.rawValue))...")
        
        do {
            // Charger les données
            loadingProgress = 0.2
            loadingMessage = "Récupération des données..."
            
            let fetchedParkings = try await ParkingService.shared.fetchParkings(type: selectedParkingType)
            totalToLoad = fetchedParkings.count
            
            loadingProgress = 0.5
            loadingMessage = "Traitement de \(fetchedParkings.count) emplacements..."
            
            // Afficher progressivement par lots de 100
            let batchSize = 100
            var loadedParkings: [Parking] = []
            
            for (index, parking) in fetchedParkings.enumerated() {
                loadedParkings.append(parking)
                loadedCount = index + 1
                
                // Mettre à jour l'affichage tous les batchSize parkings
                if loadedParkings.count % batchSize == 0 || index == fetchedParkings.count - 1 {
                    parkings = loadedParkings.sorted { $0.nom < $1.nom }
                    loadingProgress = 0.5 + (0.4 * Double(index + 1) / Double(fetchedParkings.count))
                    loadingMessage = "\(loadedCount)/\(totalToLoad) chargés"
                    
                    // Mise à jour des clusters à chaque lot
                    updateClustersIfNeeded(force: true)
                    
                    // Petit délai pour permettre le rendu UI
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }
            }
            
            // Finalisation
            loadingProgress = 1.0
            loadingMessage = "Terminé !"
            lastUpdate = Date()
            
            // Mettre en cache
            parkingsCache[selectedParkingType] = parkings
            
            // Marquer comme chargé
            switch selectedParkingType {
            case .bike:
                bikeParkingsLoaded = true
            case .motorized2Wheel:
                moto2WheelParkingsLoaded = true
            case .car:
                break
            }
            
            print("✅ ParkingViewModel: \(parkings.count) parkings \(selectedParkingType.rawValue) chargés progressivement")
            
            // Effacer le message après un court délai
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
            loadingMessage = ""
            
        } catch {
            print("⚠️ Erreur chargement progressif (non-bloquante): \(error.localizedDescription)")
            self.error = error.localizedDescription
            loadingMessage = ""
        }
    }
    
    func startAutoRefresh() {
        stopAutoRefresh()
        
        // Ne refresh que les parkings voiture (données temps réel)
        guard selectedParkingType == .car else {
            print("⏸️ ParkingViewModel: Pas de refresh auto pour \(selectedParkingType.rawValue) (données statiques)")
            return
        }
        
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                guard self.isViewActive else { return }
                try? await Task.sleep(nanoseconds: UInt64(self.refreshInterval * 1_000_000_000))
                guard !Task.isCancelled, self.isViewActive else { return }
                await self.loadParkings()
            }
        }
        
        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                guard self.isViewActive else { return }
                let startTime = Date()
                while !Task.isCancelled {
                    guard self.isViewActive else { return }
                    let elapsed = Date().timeIntervalSince(startTime)
                    let progress = min(elapsed / self.refreshInterval, 1.0)
                    let remaining = max(0, self.refreshInterval - elapsed)
                    
                    self.refreshProgress = progress
                    self.secondsUntilNextRefresh = Int(ceil(remaining))
                    
                    if elapsed >= self.refreshInterval {
                        break
                    }
                    
                    // ⚠️ Mise à jour toutes les 500ms pour réduire la charge MainActor
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
    }
    
    func onAppear() {
        isViewActive = true
        // Charger les données en arrière-plan sans bloquer l'affichage
        Task(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            // Utiliser le chargement progressif pour vélos et 2-roues
            if self.selectedParkingType == .bike || self.selectedParkingType == .motorized2Wheel {
                await self.loadParkingsProgressively()
            } else {
                await self.loadParkings()
            }
            // Le refresh auto ne démarre que pour les parkings voiture
            self.startAutoRefresh()
        }
    }
    
    func onDisappear() {
        isViewActive = false
        stopAutoRefresh()
    }
}
