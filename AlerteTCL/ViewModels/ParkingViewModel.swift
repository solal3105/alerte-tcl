import Foundation
import SwiftUI
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
    
    // État de chargement spatial (non-bloquant)
    @Published var loadingMessage: String = ""
    @Published var loadingProgress: Double = 0.0
    @Published var isLoadingInBackground = false
    @Published var loadedCount: Int = 0
    @Published var totalToLoad: Int = 0
    
    // Debounce pour éviter trop de requêtes lors du pan/zoom
    private var regionUpdateTask: Task<Void, Never>?
    private let regionUpdateDebounce: UInt64 = 300_000_000 // 300ms
    
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
    
    /// Chargement spatial pour vélos et 2-roues (charge uniquement la zone visible)
    func loadParkingsInRegion(_ region: MKCoordinateRegion) async {
        guard !isLoadingInBackground else { return }
        
        isLoadingInBackground = true
        let typeLabel = selectedParkingType == .bike ? "vélos" : "2-roues"
        loadingMessage = "Chargement \(typeLabel)..."
        loadingProgress = 0.3
        error = nil
        
        defer {
            isLoadingInBackground = false
        }
        
        do {
            let fetchedParkings = try await ParkingService.shared.fetchParkingsInRegion(
                type: selectedParkingType,
                region: region
            )
            
            // Fusionner avec les parkings existants (garder les nouveaux + ceux déjà chargés)
            var mergedParkings = parkings
            let existingIds = Set(parkings.map { $0.id })
            
            for parking in fetchedParkings {
                if !existingIds.contains(parking.id) {
                    mergedParkings.append(parking)
                }
            }
            
            parkings = mergedParkings.sorted { $0.nom < $1.nom }
            loadedCount = parkings.count
            totalToLoad = loadedCount
            lastUpdate = Date()
            
            loadingProgress = 1.0
            loadingMessage = "\(fetchedParkings.count) \(typeLabel) chargés"
            
            // Marquer comme chargé (au moins partiellement)
            switch selectedParkingType {
            case .bike:
                bikeParkingsLoaded = true
            case .motorized2Wheel:
                moto2WheelParkingsLoaded = true
            case .car:
                break
            }
            
            updateClustersIfNeeded(force: true)
            
            print("✅ ParkingViewModel: \(fetchedParkings.count) parkings \(selectedParkingType.rawValue) chargés (total: \(parkings.count))")
            
            // Effacer le message après un court délai
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s
            loadingMessage = ""
            loadingProgress = 0.0
            
        } catch {
            print("⚠️ Erreur chargement spatial: \(error.localizedDescription)")
            self.error = error.localizedDescription
            loadingMessage = ""
            loadingProgress = 0.0
        }
    }
    
    /// Chargement initial pour vélos/2-roues basé sur la région courante
    func loadParkingsProgressively() async {
        // Utiliser la région visible ou la région par défaut
        let region = visibleRegion ?? mapRegion
        await loadParkingsInRegion(region)
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
            // Pour voitures: charger tout (peu de données, temps réel)
            // Pour vélos/2-roues: attendre la première mise à jour de région
            if self.selectedParkingType == .car {
                await self.loadParkings()
            }
            // Note: vélos/2-roues seront chargés automatiquement via updateVisibleRegion
            self.startAutoRefresh()
        }
    }
    
    func onDisappear() {
        isViewActive = false
        stopAutoRefresh()
        regionUpdateTask?.cancel()
        regionUpdateTask = nil
    }
}
