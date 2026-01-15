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
    
    @Published var refreshProgress: Double = 0.0
    @Published var secondsUntilNextRefresh: Int = 300
    
    private var refreshTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    private let refreshInterval: TimeInterval = 300 // 5 minutes (non utilisé - cache journalier)
    private let cacheExpirationInterval: TimeInterval = 86400 // 24 heures
    private let clusteringConfig = ClusteringEngine.Configuration.default
    
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
    
    var travauxEnCours: Int {
        travaux.filter { $0.avancement == .enCours }.count
    }
    
    var travauxTresPerturbants: Int {
        travaux.filter { $0.importance == .tresPerturbant }.count
    }
    
    var travauxParCommune: [String: Int] {
        Dictionary(grouping: travaux) { $0.commune }
            .mapValues { $0.count }
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
        // Pas de clustering en dessous de 0.1 de zoom ET minimum 20 markers requis
        // On ignore ClusteringEngine.shouldCluster pour forcer nos propres règles
        currentZoomLevel >= 0.02 && visibleTravaux.count >= 20
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
        Task(priority: .userInitiated) {
            await loadTravaux()
            startAutoRefresh()
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
                print("✅ TravauxViewModel: Utilisation du cache (mis à jour il y a \(Int(timeSinceLastUpdate / 3600))h)")
                return
            }
        }
        
        isLoading = true
        error = nil
        
        do {
            let fetchedTravaux = try await TravauxService.shared.fetchTravaux()
            travaux = fetchedTravaux
            lastUpdate = Date()
            resetCountdown()
            
            // Forcer la mise à jour des clusters
            updateClustersIfNeeded()
            
            print("✅ TravauxViewModel: \(travaux.count) travaux chargés et mis en cache pour 24h")
        } catch {
            self.error = error.localizedDescription
            print("❌ TravauxViewModel: Erreur de chargement: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Auto Refresh
    
    private func startAutoRefresh() {
        stopAutoRefresh()
        
        // Pas de refresh auto pour les travaux - cache de 24h
        print("ℹ️ TravauxViewModel: Pas de refresh auto (cache journalier)")
        
        // Countdown timer pour afficher le temps restant avant expiration du cache
        countdownTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { break }
                
                if let lastUpdate = lastUpdate {
                    let timeSinceUpdate = Date().timeIntervalSince(lastUpdate)
                    let remaining = max(0, cacheExpirationInterval - timeSinceUpdate)
                    secondsUntilNextRefresh = Int(remaining)
                    refreshProgress = timeSinceUpdate / cacheExpirationInterval
                }
            }
        }
    }
    
    private func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
        countdownTask?.cancel()
        countdownTask = nil
    }
    
    private func resetCountdown() {
        secondsUntilNextRefresh = Int(refreshInterval)
        refreshProgress = 0.0
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
        countdownTask?.cancel()
    }
}
