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
    @Published var selectedParkingType: ParkingType = .car {
        didSet {
            if oldValue != selectedParkingType {
                // Invalider le cache de clustering pour forcer le recalcul
                invalidateClusterCache()
                Task {
                    await loadParkings()
                }
            }
        }
    }
    
    @Published var mapRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 45.764043, longitude: 4.835659),
        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    )
    
    private var refreshTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?
    private let refreshInterval: TimeInterval = 60
    
    // Configuration de clustering basée sur la densité (identique pour tous les types)
    private var clusteringConfig: ClusteringEngine.Configuration {
        .default
    }
    
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
        return parkings.visibleIn(region: visibleRegion, buffer: .standard)
    }
    
    // MARK: - Clustering
    
    @Published private(set) var cachedClusters: [MapCluster<Parking>] = []
    @Published private(set) var cachedUnclusteredParkings: [Parking] = []
    private var lastClusteringZoom: Double = 0
    private var lastClusteringParkingCount: Int = 0
    
    var shouldShowClusters: Bool {
        ClusteringEngine.shouldCluster(zoomLevel: currentZoomLevel, config: clusteringConfig)
    }
    
    private func updateClustersIfNeeded(force: Bool = false) {
        let zoomChanged = abs(currentZoomLevel - lastClusteringZoom) > 0.003
        let parkingsChanged = visibleParkings.count != lastClusteringParkingCount
        
        guard force || zoomChanged || parkingsChanged else { return }
        
        let parkingsToCluster = visibleParkings
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
        
        do {
            let fetchedParkings = try await ParkingService.shared.fetchParkings(type: selectedParkingType)
            parkings = fetchedParkings.sorted { $0.nom < $1.nom }
            lastUpdate = Date()
            secondsUntilNextRefresh = Int(refreshInterval)
            
            // Forcer la mise à jour des clusters
            updateClustersIfNeeded(force: true)
            
            print("✅ ParkingViewModel: \(parkings.count) parkings \(selectedParkingType.rawValue) chargés avec succès")
            print("📊 ParkingViewModel: Total places: \(totalPlacesDisponibles)/\(totalCapacite)")
            print("🅿️ ParkingViewModel: Parkings ouverts: \(parkingsOuverts)")
            
        } catch {
            print("❌ ParkingViewModel: Erreur de chargement: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func startAutoRefresh() {
        stopAutoRefresh()
        
        // Ne refresh que les parkings voiture (données temps réel)
        guard selectedParkingType == .car else {
            print("⏸️ ParkingViewModel: Pas de refresh auto pour \(selectedParkingType.rawValue) (données statiques)")
            return
        }
        
        refreshTask = Task {
            while !Task.isCancelled && isViewActive {
                try? await Task.sleep(nanoseconds: UInt64(refreshInterval * 1_000_000_000))
                guard !Task.isCancelled && isViewActive else { break }
                await loadParkings()
            }
        }
        
        progressTask = Task {
            while !Task.isCancelled && isViewActive {
                let startTime = Date()
                while !Task.isCancelled && isViewActive {
                    let elapsed = Date().timeIntervalSince(startTime)
                    let progress = min(elapsed / refreshInterval, 1.0)
                    let remaining = max(0, refreshInterval - elapsed)
                    
                    self.refreshProgress = progress
                    self.secondsUntilNextRefresh = Int(ceil(remaining))
                    
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
    }
    
    func onAppear() {
        isViewActive = true
        // Charger les données en arrière-plan sans bloquer l'affichage
        Task(priority: .userInitiated) {
            await loadParkings()
            // Le refresh auto ne démarre que pour les parkings voiture
            startAutoRefresh()
        }
    }
    
    func onDisappear() {
        isViewActive = false
        stopAutoRefresh()
    }
}
