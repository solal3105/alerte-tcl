import Foundation
import SwiftUI
import MapKit
import Combine

@MainActor
final class TravauxViewModel: ObservableObject {
    @Published var travaux: [Travaux] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastUpdate: Date?
    @Published var currentZoomLevel: Double = 0.15
    @Published var visibleRegion: MKCoordinateRegion?
    
    @Published var selectedNatureChantier: Set<TravauxNatureChantier> = Set(TravauxNatureChantier.allCases)
    @Published var searchText: String = ""
    
    private var refreshTask: Task<Void, Never>?
    private let cacheExpirationInterval: TimeInterval = 86400 // 24 heures
    private let clusteringConfig = ClusteringEngine.Configuration.dense
    /// Seuil de zoom au-delà duquel le clustering travaux s'active.
    /// Valeur plus haute = clusters apparaissent seulement très dézoomé.
    private let travauxClusteringZoomThreshold: Double = 0.10
    
    // MARK: - Computed Properties
    
    var filteredTravaux: [Travaux] {
        var result = travaux
        
        // Filter by nature de chantier
        result = result.filter { selectedNatureChantier.contains($0.natureChantier) }
        
        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter {
                $0.nom.localizedCaseInsensitiveContains(searchText) ||
                $0.nomChantier.localizedCaseInsensitiveContains(searchText) ||
                $0.commune.localizedCaseInsensitiveContains(searchText) ||
                $0.intervenant.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    var hasActiveFilters: Bool {
        selectedNatureChantier.count < TravauxNatureChantier.allCases.count ||
        !searchText.isEmpty
    }
    
    // MARK: - Viewport Filtering
    
    /// Travaux visibles dans la région actuelle (avec buffer très large)
    var visibleTravaux: [Travaux] {
        filteredTravaux.visibleIn(region: visibleRegion, buffer: .extraLarge)
    }
    
    // MARK: - Clustering
    
    @Published private(set) var cachedClusters: [MapCluster<Travaux>] = []
    @Published private(set) var cachedUnclusteredTravaux: [Travaux] = []
    private var lastClusteringZoom: Double = 0
    private var lastClusteringTravauxCount: Int = 0
    
    var shouldShowClusters: Bool {
        // Cluster uniquement quand très dézoomé (> 0.10) ET minimum 20 markers
        currentZoomLevel >= travauxClusteringZoomThreshold && visibleTravaux.count >= 20
    }
    
    private func updateClustersIfNeeded() {
        let zoomChanged = abs(currentZoomLevel - lastClusteringZoom) > 0.002
        let travauxChanged = visibleTravaux.count != lastClusteringTravauxCount
        
        guard zoomChanged || travauxChanged else { return }
        
        let result = ClusteringEngine.createClusters(from: visibleTravaux, zoomLevel: currentZoomLevel, config: clusteringConfig)
        cachedClusters = result.clusters
        cachedUnclusteredTravaux = result.unclustered
        lastClusteringZoom = currentZoomLevel
        lastClusteringTravauxCount = visibleTravaux.count
        
    }
    
    var clusters: [MapCluster<Travaux>] {
        cachedClusters
    }
    
    var unclusteredTravaux: [Travaux] {
        cachedUnclusteredTravaux
    }
    
    // MARK: - Display Limits
    
    private let maxDisplayMarkers = 1000
    
    var shouldShowTooManyMarkersWarning: Bool {
        // Compter TOUS les travaux visibles (pas les markers)
        return visibleTravaux.count > maxDisplayMarkers
    }
    
    var displayClusters: [MapCluster<Travaux>] {
        guard !shouldShowTooManyMarkersWarning && shouldShowClusters else { return [] }
        return clusters
    }
    
    var displayTravaux: [Travaux] {
        guard !shouldShowTooManyMarkersWarning else { return [] }
        // Si on ne doit pas clusterer, afficher tous les travaux visibles
        return shouldShowClusters ? unclusteredTravaux : visibleTravaux
    }
    
    /// Travaux qui ne sont PAS dans des clusters (pour afficher les polygones)
    var nonClusteredTravaux: [Travaux] {
        guard !shouldShowTooManyMarkersWarning else { return [] }
        
        if !shouldShowClusters {
            // Pas de clustering = tous les travaux sont non-clusterés
            return visibleTravaux
        }
        
        // Récupérer tous les IDs des travaux dans les clusters
        let clusteredIds = Set(cachedClusters.flatMap { $0.items.map { $0.id } })
        
        // Retourner les travaux visibles qui ne sont PAS dans les clusters
        return visibleTravaux.filter { !clusteredIds.contains($0.id) }
    }
    
    func updateZoomLevel(_ span: MKCoordinateSpan) {
        currentZoomLevel = span.latitudeDelta
        updateClustersIfNeeded()
    }
    
    func updateVisibleRegion(_ region: MKCoordinateRegion) {
        visibleRegion = region
        updateClustersIfNeeded()
    }
    
    // MARK: - Lifecycle
    
    func onAppear() {
        // Charger les données en arrière-plan sans bloquer l'affichage
        Task(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            await self.loadTravaux()
            self.startAutoRefresh()
        }
    }
    
    func onDisappear() {
        stopAutoRefresh()
    }
    
    // MARK: - Data Loading
    
    func loadTravaux() async {
        // Vérifier si le cache est encore valide (< 24h)
        if let lastUpdate = lastUpdate {
            let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdate)
            if timeSinceLastUpdate < cacheExpirationInterval && !travaux.isEmpty {
                AppLogger.debug("✅ TravauxViewModel: Utilisation du cache (mis à jour il y a \(Int(timeSinceLastUpdate / 3600))h)")
                return
            }
        }
        
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let fetchedTravaux = try await TravauxService.shared.fetchTravaux()
            travaux = fetchedTravaux
            lastUpdate = Date()
            
            // Forcer la mise à jour des clusters
            updateClustersIfNeeded()
            
            AppLogger.debug("✅ TravauxViewModel: \(travaux.count) travaux chargés et mis en cache pour 24h")
        } catch {
            self.error = error.localizedDescription
            AppLogger.debug("⚠️ Erreur travaux (non-bloquante): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Auto Refresh
    
    private func startAutoRefresh() {
        stopAutoRefresh()
        
        // Pas de refresh auto pour les travaux - cache de 24h
        AppLogger.debug("ℹ️ TravauxViewModel: Pas de refresh auto (cache journalier)")
    }
    
    private func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
    
    // MARK: - Filters
    
    func toggleNatureChantier(_ nature: TravauxNatureChantier) {
        if selectedNatureChantier.contains(nature) {
            selectedNatureChantier.remove(nature)
        } else {
            selectedNatureChantier.insert(nature)
        }
    }
    
    func resetFilters() {
        selectedNatureChantier = Set(TravauxNatureChantier.allCases)
        searchText = ""
    }
    
    deinit {
        refreshTask?.cancel()
    }
}
