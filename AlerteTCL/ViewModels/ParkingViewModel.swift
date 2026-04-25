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
                invalidateClusterCache()
                error = nil
                
                // 2. Annuler tout chargement en cours
                currentLoadTask?.cancel()
                regionUpdateTask?.cancel()
                
                // 3. Gérer l'auto-refresh (seulement voitures)
                stopAutoRefresh()
                if selectedParkingType == .car {
                    startAutoRefresh()
                }
                
                // 4. Charger les nouvelles données (cache-first, viewport-first)
                currentLoadTask = Task { [weak self] in
                    guard let self, !Task.isCancelled else { return }
                    
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
    
    // Cache par type pour éviter de recharger
    private var parkingsCache: [ParkingType: [Parking]] = [:]
    
    @Published var mapRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 45.764043, longitude: 4.835659),
        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    )
    
    private var refreshTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?
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

        let visible = visibleParkings
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
    
    func startAutoRefresh() {
        stopAutoRefresh()
        
        // Ne refresh que les parkings voiture (données temps réel)
        guard selectedParkingType == .car else {
            AppLogger.debug("⏸️ ParkingViewModel: Pas de refresh auto pour \(selectedParkingType.rawValue) (données statiques)")
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
                    let remaining = max(0, self.refreshInterval - elapsed)
                    
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
        currentLoadTask?.cancel()
        currentLoadTask = Task(priority: .userInitiated) { [weak self] in
            guard let self = self, !Task.isCancelled else { return }
            
            // Restaurer depuis le cache immédiatement si disponible
            if let cached = self.parkingsCache[self.selectedParkingType], !cached.isEmpty, self.parkings.isEmpty {
                self.parkings = cached
                self.updateClustersIfNeeded(force: true)
            }
            
            // Pour voitures: toujours charger (temps réel)
            // Pour vélos/2-roues: charger via updateVisibleRegion
            if self.selectedParkingType == .car {
                await self.loadParkings()
            } else if self.parkings.isEmpty {
                await self.loadParkingsProgressively()
            }
            self.startAutoRefresh()
        }
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
